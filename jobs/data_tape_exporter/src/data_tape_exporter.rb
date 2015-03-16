require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require 'csv'
require 'date'

class DataTapeExporter < Job

	def initialize(options, logger)
		super(options, logger)
	end

	def execute!
		export_folder_path = "#{ENV['RUNNER_PATH']}/#{@options['export_path']}"

		Dir.chdir(export_folder_path)
		
		@logger.info "Logging into Salesforce"

		restforce_client = get_restforce_client(@options['salesforce']['external']['development'], true)
		client = restforce_client[:client]

		@logger.info "Login successful"
		
		# Retrieve todays batch jobs track batch ids and enrollment ids for later use
		batch_ids = []
		batch_to_enrollment = {}

		batches = client.query("SELECT Id, Program_Enrollment__c FROM Batch_Load_Job__c WHERE Date_to_Load__c = #{Date.today.to_s}")
		batches.each do |batch|
			batch_ids << batch.Id
			batch_to_enrollment[batch.Id] = batch.Program_Enrollment__c
		end

		@logger.info "Batch IDs to pull down: #{batch_ids}"

		# Get chatter files associated with chatter files
		files = client.get '/services/apexrest/BatchLoad', :batchIds => batch_ids.to_s
		run_time = DateTime.now.strftime('%Y%m%d%H%M%S')

		files.body.each do |dataTape|
			unless dataTape.ContentType.nil? || dataTape.ContentType != 'text/csv'
				filepath = "#{run_time}_#{dataTape.Id}.csv"
				content = client.get dataTape.ContentData
				body = content.body

				CSV.open(filepath, "wb") do |csv|
					CSV.parse(body).each do |row|
						csv << row
					end
				end
			end
		end
		@logger.info "Successfully completed"
	end

	private



end