require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require "#{ENV['RUNNER_PATH']}/lib/logger.rb"
require 'net/sftp'
require 'base64'
require 'date'
require 'net/smtp'

class DocUploads < Job
	def initialize(options, logger)
		super(options, logger)
	end

	def execute!

		@@fldMap = {
			"FHW" => {
				"title" => "Final HUD Packages",
				"folder" => "Offer",
				"fields" => ["Final_HUD_Reviewed_Date__c", "Final_HUD_Upload_Date__c"]
			},
			"CTU" => {
				"title" => "Unexecuted Contracts",
				"folder" => "Offer",
				"fields" => ["Contract_To_Seller__c"]
			},
			"CTE" => {
				"title" => "Executed Contracts",
				"folder" => "Offer",
				"fields" => ["Date_PSA_Fully_Executed__c"]
			},
			"EHUD" => {
				"title" => "Est. HUD Package",
				"folder" => "Offer",
				"fields" => [""]
			},
			"PTR" => {
				"title" => "Property Title Reports",
				"folder" => "Auction",
				"fields" => ["PTR_Upload_Date__c"]
			}
		}

		@@dml_log = {
			"auction" => [],
			"offer" => []
	    }

	    @@file_log = {
	    	"processed" => [],
	    	"failed" => []
	    }
		
		# Restforce.log = true
		restforce_client = get_restforce_client(@options['salesforce']['external']['development'], true)
		@@client = restforce_client[:client]

		@logger.info "Login successful"		

		Net::SFTP.start(@options['sftp']['closing']['host'], @options['sftp']['closing']['username'], :password => @options['sftp']['closing']['password']) do |sftp|
			files = []

			# iterate through offer dropbox directory
			sftp.dir.foreach("Offer/dropbox") do |file|
				if file.name =~ /^*\.pdf$/ then

			    	filename = File.basename(file.name)
			    	file_key = filename[/-(.*?)\.\w+$/,1]
			    	record_id = filename[/^(.*?)-/,1]

					@@file_log["processed"] << filename

			    	if @@fldMap.has_key?(file_key) && !record_id.nil? && (record_id.length == 18 || record_id.length == 15) then
			    		files << filename			    		
			    	else
			    		@logger.info "ERROR: "+filename+" Incorrect naming convention"	
			    		sftp.rename!("Offer/dropbox/"+filename, "Offer/failed/"+filename)
			    		@@file_log["failed"] << filename
			    	end
			    end    	
		  	end

			# iterate through auction dropbox directory
			sftp.dir.foreach("Auction/dropbox") do |file|
				if file.name =~ /^*\.pdf$/ then

			    	filename = File.basename(file.name)
			    	file_key = filename[/-(.*?)\.\w+$/,1]
			    	record_id = filename[/^(.*?)-/,1]

			    	@@file_log["processed"] << filename

			    	if @@fldMap.has_key?(file_key) && !record_id.nil? && record_id.length > 0 then
			    		files << filename			    		
			    	else
			    		@logger.info "ERROR: "+filename+" Incorrect naming convention"
			    		sftp.rename!("Auction/dropbox/"+filename, "Auction/failed/"+filename)
			    		@@file_log["failed"] << filename
			    	end
			    end    	
		  	end

		  	#map to maintain objects for update in case multiple files exist for the same id
		  	offers_for_update = {}
		  	auctions_for_update = {}

		    #post feed items and stamp dates to salesforce
		    if !files.empty? then
		    	files.each do |file|

		    		puts file	    		

		    		file_key = file[/-(.*?)\.\w+$/,1]
		    		record_id = file[/^(.*?)-/,1]
		    		file_name = @@fldMap[file_key]["title"]
		    		folder = @@fldMap[file_key]["folder"]

		    		if record_id.length > 0
				    	data = sftp.download!(folder+"/dropbox/"+file)

				    	#set the date field on the offer instance
				    	record_for_update = {}

				    	if folder == "Offer" then
				    		offer = offers_for_update.has_key?(record_id) ? offers_for_update[record_id] : { "Id" => record_id }
				    		offers_for_update[record_id] = offer

				    		record_for_update = offer
				    	end

				    	if folder == "Auction" then
				    		auction = auctions_for_update.has_key?(record_id) ? auctions_for_update[record_id] : { "Id" => record_id }
				    		auctions_for_update[record_id] = auction

				    		record_for_update = auction
				    	end

						@@fldMap[file_key]["fields"].each do |fld|
							record_for_update[fld] = Date.today
						end

				    	#create the feed item
						begin
							res = @@client.create!("FeedItem", ParentId: record_id, ContentData: Base64::encode64(data), ContentFileName: file_name, Body: file_name, Visibility: 'AllUsers')

						rescue => e
							puts e.inspect
							sftp.rename!(folder+"/dropbox/"+file, folder+"/failed/"+file)

							@@file_log["failed"] << filename
						end
					end					

					# move the file to the processed folder
					sftp.rename!(folder+"/dropbox/"+file, folder+"/complete/"+file)
				end
		    end

		    #update the offer records
		    if !offers_for_update.empty? then
			    offers_for_update.keys.each do |record_id|
					offer = offers_for_update[record_id]

					begin
						res = @@client.update!("Offer__c", offer)
					rescue => e
						@@dml_log["offer"] << record_id
						puts e.inspect
					end
				end
			end

			#update the auction records
		    if !auctions_for_update.empty? then
			    auctions_for_update.keys.each do |record_id|
					auction = auctions_for_update[record_id]

					begin
						res = @@client.update!("Auction__c", auction)
					rescue => e
						@@dml_log["auction"] << record_id
						puts e.inspect
					end
				end
			end
		end

		# if !@@dml_log.empty? then
			# @logger.info "ERROR: dml failed for the following record ids| "+@@dml_log
		# end
	end
end