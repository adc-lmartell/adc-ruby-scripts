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