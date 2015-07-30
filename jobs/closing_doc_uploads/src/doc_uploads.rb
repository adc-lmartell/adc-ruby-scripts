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
			"Final HUD Packages" => ["Final_HUD_Reviewed_Date__c", "Final_HUD_Upload_Date__c"],
			"Unexecuted Contracts" => ["Contract_To_Seller__c"],
			"Executed Contracts" => ["Date_PSA_Fully_Executed__c"],
			"Property Title Reports" => ["PTR_Upload_Date__c"]
		}

		@@dml_log = {
	    	"file" => {
	    		"successes" => [],
	    		"failures" => []
	    	},
	    	"offer" => {
	    		"successes" => [],
	    		"failures" => []
	    	}
	    }
		
		# Restforce.log = true
		restforce_client = get_restforce_client(@options['salesforce']['external']['development'], true)
		@@client = restforce_client[:client]

		@logger.info "Login successful"		

		Net::SFTP.start(@options['sftp']['closing']['host'], @options['sftp']['closing']['username'], :password => @options['sftp']['closing']['password']) do |sftp|
			files = []
			offer_nums = []

			# collect offer auto numbers
			sftp.dir.foreach("/Closing Document Uploads/dropbox") do |file|
				if file.name =~ /^*\.pdf$/ then

			    	filename = File.basename(file.name)
			    	closing_file = filename[/-(.*?)\.\w+$/,1]
			    	
			    	if @@fldMap.has_key?(closing_file) then
			    		files << filename
			    		offer_num = filename[/^(.*?)-/,1]
			    		offer_nums << offer_num if offer_nums.index(offer_num).nil?			    		
			    	else
			    		sftp.rename!("Closing Document Uploads/dropbox/"+file, "Closing Document Uploads/error/"+file)
						@@dml_log["file"]["failures"] << offer_num
			    	end
			    end    	
		  	end

		  	#map to maintain offer objects to update in case multiple files exist for one offer

		  	offers_for_update = {}

		  	#collect hash of offer names to ids
		  	offer_ids = fetch_offer_ids(offer_nums)		  	

		    #post feed items and stamp dates to salesforce
		    if !files.empty? then
		    	files.each do |file|		    		

		    		closing_file = file[/-(.*?)\.\w+$/,1]
		    		offer_num = file[/^(.*?)-/,1]
		    		offer_id = offer_ids.has_key?(offer_num) ? offer_ids[offer_num] : ''
		    		puts offer_id
		    		if offer_id.length > 0
				    	data = sftp.download!("/Closing Document Uploads/dropbox/"+file)

				    	#set the date field on the offer instance
				    	offer = offers_for_update.has_key?(offer_id) ? offers_for_update[offer_id] : { "Id" => offer_id }
				    	offers_for_update[offer_id] = offer

						@@fldMap[closing_file].each do |fld|
							offer[fld] = Date.today
						end

				    	#create the feed item
						begin
							res = @@client.create!("FeedItem", ParentId: offer_id, ContentData: Base64::encode64(data), ContentFileName: closing_file, Body: closing_file, Visibility: 'AllUsers')
							if res.length == 18 then
								@@dml_log["file"]["successes"] << offer_num
							end

						rescue => e
							puts e.inspect
							sftp.rename!("Closing Document Uploads/dropbox/"+file, "Closing Document Uploads/error/"+file)
							@@dml_log["file"]["failures"] << offer_num
						end
					end					

					# move the file to the processed folder
					sftp.rename!("Closing Document Uploads/dropbox/"+file, "Closing Document Uploads/processed/"+file)
				end
		    end

		    #update the offer records
		    offers_for_update.keys.each do |offer_id|
				offer = offers_for_update[offer_id]
				puts offer

				begin
					res = @@client.update!("Offer__c", offer)
				rescue => e
					puts e.inspect
				end
			end
		end
	end

	#fetch offer ids filtered by names and return a map of offer name to offer id
	def fetch_offer_ids(offer_nums)

		offer_hash = {}
	  	offer_nums_str = ''	  	

	  	begin
		    offer_nums.each do |num|
		    	offer_nums_str += (offer_nums_str.length == 0) ? '\''+num+'\'' : ',\''+num+'\''
		    end

		    if offer_nums_str.length > 0 then
		    	offers = @@client.query('SELECT Id, Name FROM Offer__c WHERE Name IN ('+offer_nums_str+')')		    	

		    	offers.each do |offer|	    		
		    		offer_hash[offer.Name] = offer.Id
		    	end
		    end
		rescue => e
			puts e.inspect
		end

	    offer_hash
	end
end