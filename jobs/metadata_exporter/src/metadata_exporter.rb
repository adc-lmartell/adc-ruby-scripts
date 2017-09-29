require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require 'csv'

class MetadataExporter < Job

	def initialize(options, logger)
		super(options, logger)
	end

	def execute!
		export_folder_path = "#{ENV['RUNNER_PATH']}/#{@options['export_path']}"

		@logger.info "Logging into Salesforce"

		restforce_client = get_restforce_client(@options['salesforce']['external']['production'], true)
		client = restforce_client[:client]

		@logger.info "Login successful"
		
		##
		# One time export to pull AE Feed Item Changes
		#
		# events = client.query("select Id, ParentId, CreatedDate, (select Id, FieldName, NewValue, OldValue from feedtrackedchanges) from Auction_Event__Feed where type = 'TrackedChange' and createddate >= 2017-01-05T00:00:00.000Z")

		# CSV.open("#{export_folder_path}/auction_event_tracked_changes.csv", "wb") do |csv|
		# 	csv << ['Auction Event ID', 'Related Record ID', 'Created Date', 'Feed Item ID', 'Field API Name', 'Old Value', 'New Value', 'Created Date']
		# 	events.each do |event|
		# 		event.FeedTrackedChanges.each do |ftc| 
		# 			csv << [event.Id, event.ParentId, event.CreatedDate, ftc.Id, ftc.FieldName, ftc.OldValue, ftc.NewValue]
		# 		end
		# 	end
		# end

		so_descs = client.describe
		so_list = []

		so_descs.each do |so_desc|
			so_list << client.describe(so_desc.name)
		end

		CSV.open("#{export_folder_path}/AllObjects.csv", "wb") do |obj_csv|
			obj_csv << ["Object Name", "Field Label", "Field Name", "Type", "External ID", "Length", "Digits", "Precision", "Formula", "Reference To", "Picklist?"]

			so_list.each do |so|
				so.fields.each do |field|
					obj_csv << [
						so.name, 
						field.label, 
						field.name, 
						field.type, 
						(field.externalId == "false" ? 0 : 1), 
						field.length, 
						field.digits, 
						field.precision, 
						field.calculatedFormula,
						(field.referenceTo.empty? ? "" : field.referenceTo.first),
						(field.picklistValues.empty? ? 0 : 1)
					]
				end
			end
		end

		CSV.open("#{export_folder_path}/AllObjectPicklists.csv", "wb") do |pl_csv|
			pl_csv << ["Object Name", "Field Label", "Field Name", "Picklist Value", "Default?", "Active?"]

			so_list.each do |so|
				so.fields.each do |field|
					unless field.picklistValues.empty? then
						field.picklistValues.each do |pli|
							pl_csv << [
								so.name, 
								field.label, 
								field.name, 
								pli.value,
								pli.default,
								(pli.active == "false" ? 0 : 1)
							]
						end
					end
				end
			end
		end
		
		@logger.info "Successfully completed"
	end

end