require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require "#{ENV['RUNNER_PATH']}/lib/logger.rb"
require "#{ENV['RUNNER_PATH']}/lib/formatter.rb"
require 'find'
require 'csv'
require 'date'
require 'json'

class FieldDescribe
	attr_accessor :dest_api, :type
	def initialize(dest, type)
		@dest_api = dest
		@type = type
	end
end

class DataTapeLoader < Job

	def initialize(options, logger)
		super(options, logger)
	end

	def execute!
		export_folder_path = "#{ENV['RUNNER_PATH']}/#{@options['export_path']}"

		Dir.chdir(export_folder_path)

		@logger.info "Logging into Salesforce"

		# Restforce.log = true
		restforce_client = get_restforce_client(@options['salesforce']['external']['development'], true)
		client = restforce_client[:client]

		@logger.info "Login successful"

		src_to_dest = {}

		fields = client.query("SELECT Id, Source_Field__c, Destination_Field__c, Program_Enrollment__c, Field_Type__c FROM Intake_Field__c WHERE Active__c = #{true}")
		fields.each do |field|
			src_to_dest[field.Program_Enrollment__c] = {} if !src_to_dest.has_key?(field.Program_Enrollment__c)
			src_to_dest[field.Program_Enrollment__c][field.Source_Field__c] = FieldDescribe.new(field.Destination_Field__c,field.Field_Type__c)
		end

		run_time = DateTime.now.strftime('%Y%m%d')

		batch_results = {}

		Dir.foreach(".") do |f|	
			# if f.match(/#{run_time}\w+\.csv\Z/) then
			if f.match(/\.csv\Z/) then
				CSV.foreach(f, headers: true) do |row|
					
					asset = {}
					row_num = $.
					attributes = row.to_hash
					enrollment_id = attributes["Program_Enrollment__c"]
					batch_id = attributes["Batch_Load_Job__c"]


					if !batch_results.has_key?(batch_id) then
						batch_results[batch_id] = {"Successes" => 0, "Failures" => 0}

						# instantiate the log file
						BatchLog.new(batch_id)
					end

					if !enrollment_id.nil? then 	
						fld_map = src_to_dest[enrollment_id]

						attributes.each do |src_field,val|	

							if fld_map.has_key?(src_field) then
								
								dest_fld = fld_map[src_field].dest_api
								fld_type = fld_map[src_field].type								

								#strip common unnecessary charactors from the value 								
								val = SfdcFormat::SfdcRegexEnforcer.format_field(val, fld_type)	

								#if an invalid format is detected, wipe the value so the load to sfdc does not fail and log the failure on the record
								if !SfdcFormat::SfdcRegexEnforcer.valid_field?(val, fld_type) then
									if asset["Processing_Errors__c"].nil? then
										asset["Processing_Errors__c"] = ""
									end

									asset["Processing_Errors__c"] += "[FIELD_TYPE_ERROR] invalid format on column\: #{src_field} with value\: #{val}  \|  "
									val = nil
								end

								asset[dest_fld] = val
							end
						end					
						
						if !asset.empty? then 

							asset_json = JSON.generate(asset)

							begin								
								res = client.create("Asset_Staging__c", asset_json)
								batch_results[batch_id]["Successes"] += 1 if res.length == 18
								raise SfdcDmlError, "Salesforce rejected the insert operation. Validate field formatting is correct." if res == false

							rescue SfdcDmlError => e
								@logger.info "Local file operation failed: #{e}"

								batch_results[batch_id]["Failures"] += 1
								BatchLog.log_exception(batch_id, "[ROW #{row_num}] "+e.message)

							rescue RuntimeError => e
								@logger.info "Local file operation failed: #{e}"

								batch_results[batch_id]["Failures"] += 1
								BatchLog::log_exception(batch_id,"[ROW #{row_num}] Chron Job quit unexpectedly due to a RuntimeError on the local machine")								
							end
						end
					end
				end
			end
		end

		#commit status and logfile with errors to salesforce
		batch_results.keys.each do |batchid|	
		
			results = batch_results[batchid]
			success = results["Successes"]
			fails = results["Failures"]

			if fails == 0 && success > 0
				status = "Completed"
			elsif fails > 0 && success > 0
				status = "Partial Completion"
			elsif fails > 0 && success == 0
				status = "Failed"
			end
			
			#add success log to the process log file
			BatchLog.log_info(batchid, "Operation #{status} with #{success} successes and #{fails} failures")

			#get the log json and create the records
			json = BatchLog.get_log_json(batchid)
			client.create("Batch_Process_Log__c", json)
			client.update("Batch_Load_Job__c", Id: batchid, Status__c: status)
		end
	end
end