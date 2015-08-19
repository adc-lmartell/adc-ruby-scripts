require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require "#{ENV['RUNNER_PATH']}/lib/logger.rb"
require 'net/sftp'
require 'date'
require 'base64'
require 'date'

class DocUploads < Job

	CLS_FTP_CONFIG = {
		"Offer" => {
			"sobject" => "Offer__c",
			"files" => {
				"FHW" => {
					"title" => "Final HUD Packages",				
					"fields" => ["Final_HUD_Reviewed_Date__c", "Final_HUD_Upload_Date__c"]
				},
				"CTU" => {
					"title" => "Unexecuted Contracts",
					"fields" => ["Contract_To_Seller__c"]
				},
				"CTE" => {
					"title" => "Executed Contracts",
					"fields" => ["Date_PSA_Fully_Executed__c"]
				}
			}
		},
		"TRL" => {
			"sobject" => "Title_Research__c",
			"files" => {
				"PTR" => {
					"title" => "Property Title Reports",
					"fields" => ["PTR_Received_Date__c"]
				}
			}
		},
		"Auction" => {
			"sobject" => "Auction__c",
			"files" => {
				"PTR" => {
					"title" => "Property Title Reports",
					"fields" => ["PTR_Upload_Date__c"]
				}
			}
		}
	}

	class InvalidFileError < RuntimeError
	end

	def initialize(options, logger)
		super(options, logger)		
	end

	def execute!
		
		restforce_client = get_restforce_client(@options['salesforce']['external']['development'], true)
		@restforce = restforce_client[:client]
		@logger.info "Login successful"		
		
		#parse SFTP site and collect a set of objects and documents for updates in each folder
		@sfdc_object_updates = {}

		Net::SFTP.start(@options['sftp']['closing']['host'], @options['sftp']['closing']['username'], :password => @options['sftp']['closing']['password']) do |sftp|
			@sftp = sftp

			@sftp.dir.foreach("/") do |dir|
				if dir.name.match(/\.\w+/).nil? && CLS_FTP_CONFIG.has_key?(dir.name) then
					begin
						ftp_dir = Directory.new dir.name
						ftp_dir.sftp = @sftp
						ftp_dir.parse!

						@sfdc_object_updates[dir.name] = ftp_dir						
					rescue Net::SFTP::StatusException => e
						@logger.info "Invalid Directory "+dir.name
					end
				end
			end
		
			#create auction documents and objects for Ohio Wells Fargo properties
			if @sfdc_object_updates.has_key?("TRL") && !@sfdc_object_updates["TRL"].documents.empty? then

				tr_ids = @sfdc_object_updates["TRL"].objects.keys				
				trs_to_auctions = query_auctions_from_tr(tr_ids)				

				if !trs_to_auctions.empty? then
					auc_directory = build_auction_directory(trs_to_auctions)				
					@sfdc_object_updates["Auction"] = auc_directory
				end
			end

			#insert files and update sobjects
			if !@sfdc_object_updates.empty? then
				@sfdc_object_updates.keys.each do |folder|
					directory = @sfdc_object_updates[folder]
					sobject_type = CLS_FTP_CONFIG[folder]["sobject"]
					
					#insert feed items
					directory.documents.values.each do |documents|						
						documents.each do |doc|
							begin								
								res = @restforce.insert("FeedItem", doc)
								raise RuntimeError, "Failed to push feed item to SFDC: "+doc["ContentFileName"] if !res
								@sftp.rename!(folder+"/dropbox/"+doc["ContentFileName"], folder+"/complete/"+doc["ContentFileName"]) if res != "false"

							rescue Net::SFTP::StatusException
								@logger.info "Failed to rename file: #{doc["ContentFileName"]} in directory: #{folder}"
							rescue => e								
								begin
									@sftp.rename!(folder+"/dropbox/"+doc["ContentFileName"], folder+"/failed/"+doc["ContentFileName"])
								rescue Net::SFTP::StatusException
									@logger.info "Failed to rename file: #{doc["ContentFileName"]} in directory: #{folder}"
								end
							end
						end
					end

					# update objects
					directory.objects.values.each do |obj|
						begin
							res = @restforce.update(sobject_type, obj)
							raise RuntimeError, "Failed to update record in SFDC: #{obj["Id"]}" if !res				
						rescue => e
							@logger.info "Failed to update record in SFDC: #{obj["Id"]}"
						end
					end
				end
			end
		end
	end

	def query_auctions_from_tr(tr_ids)

		trs_to_auctions = {}
		query_str = 'SELECT Id, Auction__c, Property_State__c FROM Title_Research__c WHERE Program_Record_Type__c = \'WFC 2nd Look Flow\' AND (Property_State__c =\'Ohio\' OR Property_State__c =\'OH\') AND Id IN '

		tr_ids.each do |tr_id|
			query_str << '(\''+tr_id+'\',' if tr_ids.index(tr_id) == 0
			query_str << '\''+tr_id+'\',' if tr_ids.index(tr_id) > 0 && tr_ids.index(tr_id) < (tr_ids.length - 1)
			query_str << '\''+tr_id+'\''+')' if tr_ids.index(tr_id) == (tr_ids.length - 1)
		end

		sobjects = @restforce.query(query_str)

		sobjects.each do |tr|
			trs_to_auctions[tr["Id"]] = tr["Auction__c"]
		end

		trs_to_auctions
	end

	def build_auction_directory(trs_to_auctions)
		if !trs_to_auctions.empty? then
			tr_directory = @sfdc_object_updates["TRL"]
			auc_objects = {}
			auc_documents = {}

			trs_to_auctions.keys.each do |tr_id|
				auc_id = trs_to_auctions[tr_id]
				auc_objects[auc_id] = {"Id" => auc_id, "PTR_Upload_Date__c" => Date.today}
				auc_documents[auc_id] = []

				tr_documents = (!tr_directory.documents.has_key?(tr_id) && tr_directory.documents.has_key?(tr_id[0,15])) ? tr_directory.documents[tr_id[0,15]] : tr_directory.documents[tr_id]

				tr_documents.each do |feed_item|
					auc_feed_item = {"ParentId" => auc_id, "ContentData" => feed_item["ContentData"], "ContentFileName" => feed_item["ContentFileName"], "Body" => feed_item["Body"], "Visibility" => "AllUsers"}
					auc_documents[auc_id] << auc_feed_item
				end
			end

			auc_directory = Directory.new "Auction"
			auc_directory.objects = auc_objects
			auc_directory.documents = auc_documents

			auc_directory
		end
	end

	class Directory

		attr_accessor :sftp, :objects, :documents, :dir

		def initialize(dir)
			@dir = dir		
			@objects = {}
			@documents = {}
		end

		def parse!
			@sftp.dir.foreach(@dir+"/dropbox") do |file|
				begin
					if file.name =~ /^*\.pdf$/ then

				    	filename = File.basename(file.name)
				    	file_type = filename[/-(.*?)\.\w+$/,1]
				    	record_id = filename[/^(.*?)-/,1]

				    	raise InvalidFileError, "Invalid file abbreviation" if !CLS_FTP_CONFIG[@dir]["files"].has_key?(file_type)
				    	raise InvalidFileError, "Invalid salesforce record Id" if record_id.nil? || (record_id.length != 18 && record_id.length != 15)

			    		#add a new feed item
			    		data = @sftp.download!(@dir+"/dropbox/"+filename)

			    		if !@documents.has_key?(record_id) then
			    			@documents[record_id] = []
			    		end

			    		@documents[record_id] << {"ParentId" => record_id, "ContentData" => Base64::encode64(data), "ContentFileName" => filename, "Body" => CLS_FTP_CONFIG[@dir]["files"][file_type]["title"], "Visibility" => "AllUsers"}

			    		#add the fields to the record
			    		object = @objects.has_key?(record_id) ? @objects[record_id] : { "Id" => record_id }
						CLS_FTP_CONFIG[@dir]["files"][file_type]["fields"].each do |fld|
							object[fld] = Date.today
						end

						@objects[record_id] = object
				    end   
				rescue => e
					@sftp.rename!(@dir+"/dropbox/"+file.name, @dir+"/failed/"+file.name)
				end
		  	end			
		end
	end
end