require "#{ENV['RUNNER_PATH']}/lib/job.rb"


class OfferMcdsTrueUp < Job

	def initialize(options, logger)
		super(options, logger)
		@auth_token = nil
	end

	def execute!

		# Login to SFDC for the records that need processed
		@logger.info "Logging into Salesforce"

		begin
			restforce_client = get_restforce_client(@options['salesforce']['external']['production'], true)
			client = restforce_client[:client]

			# Pull the offers that need updated
			offers = client.query("SELECT Id, Property_ID__c, Transaction_ID__c, Online_Contract_Form_Complete__c, MCDS_Sent_to_Buyer_Date__c, MLH_DocuSign_Status__c, MLH_DocuSign_Envelope_ID__c, MLH_DocuSign_Status_Date__c, Unsigned_Docusign_Contract_URL__c, Signed_Docusign_Contract_URL__c, Original_MCDS_to_Buyer_Date__c FROM Offer__c WHERE Property_ID__c != null AND Transaction_ID__c = null AND Is_Winning_Bid__c = 'Yes' AND Bid_Date_Time__c >= LAST_N_DAYS:120 AND Auction_Event__r.Program_Enrollment__r.MCDS_Enabled__c = true LIMIT 1")

			unless offers.size == 0
				offers.each do |offer|
					contract_info = get_contract_status(offer.Property_ID__c)
					unless contract_info.nil?
						save_sf_record(offer, contract_info)
					end
				end
			end

		rescue Exception => e
			@logger.error "Error: #{e}"
		end

		@logger.info "Successfully completed"
	end

	private

	def get_contract_status(listing_id)
		unless @auth_token.nil?

		end
	end

	def save_sf_record(offer, contract_status)
		# Set fields
		offer.save
	end

end