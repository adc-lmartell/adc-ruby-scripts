require "#{ENV['RUNNER_PATH']}/lib/job.rb"

class AuctionSellerUpdate < Job

	def initialize(options, logger)
		super(options, logger)
	end

	def execute!

		# Login to SFDC for the records that need processed
		@logger.info "Logging into Salesforce"

		begin
			restforce_client = get_restforce_client(@options['salesforce']['external']['production'], true)
			client = restforce_client[:client]

			# Query for Auction records that need the PRT field flipped
			auc_updates = client.query("SELECT Id, Program_Record_Type__c, RecordType.Name FROM Auction__c WHERE Seller__c = null AND Tracking_ID__c LIKE '%RHF%' AND CreatedDate = LAST_N_DAYS:10 AND RecordType.Name <> 'REMOVED'")

			unless auc_updates.first.nil?

				# Flip PRT to blank so we can re-trigger the Seller stamp WFR 
				auc_updates.each do |au|
					client.update('Auction__c', Id: au.Id, Program_Record_Type__c: nil)
				end

				# Flip the PRT back to what it was originally
				auc_updates.each do |au|
					client.update('Auction__c', Id: au.Id, Program_Record_Type__c: au.Program_Record_Type__c)
				end
			end

		rescue Exception => e
			puts e.inspect
			@logger.error "Error: #{e}"
		end

		@logger.info "Successfully completed"
	end

end
