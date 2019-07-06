require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require 'net/https'
require 'json'
require 'uri'

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
			offers = client.query("SELECT Id, Auction_Event__r.MLH_Property_ID__c, Transaction_ID__c, Online_Contract_Form_Complete__c, MCDS_Sent_to_Buyer_Date__c, MLH_DocuSign_Status__c, MLH_DocuSign_Envelope_ID__c, MLH_DocuSign_Status_Date__c, Unsigned_Docusign_Contract_URL__c, Signed_Docusign_Contract_URL__c, Original_MCDS_to_Buyer_Date__c FROM Offer__c WHERE Property_ID__c != null AND Transaction_ID__c = null AND Is_Winning_Bid__c = 'Yes' AND Bid_Date_Time__c >= LAST_N_DAYS:120 AND Auction_Event__r.Program_Enrollment__r.MCDS_Enabled__c = true LIMIT 1")

			unless offers.size == 0
				offers.each do |offer|
					contract_info = get_contract_status({
						'listing_id' => offer.Auction_Event__r.MLH_Property_ID__c
					})
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

	def format_url_params(params)
		params.map { |k,v| "#{k}=#{v}" }.join('&')
	end

	def get_auth_token(params)
		auth_token = nil

		headers = {
			'Content-Type' => 'application/json',
			'Accept' => 'application/json'
		}
		uri = URI.parse("#{@options['uaa']['endpoint']}?#{format_url_params(params)}")
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		http.verify_mode = OpenSSL::SSL::VERIFY_NONE
		request = Net::HTTP::Post.new(uri.request_uri, headers)
		request.body = @options['uaa']['grant_type']
		response = http.request(request)
		auth_response = JSON.parse(response.body)

		if auth_response.has_key?('access_token')
			auth_token = auth_response['access_token']
		end

		return auth_token
	end

	def get_contract_status(params)
		contract_info = nil

		if @auth_token.nil?
			@auth_token = get_auth_token({
				'grant_type' => @options['uaa']['grant_type'],
				'client_id' => @options['uaa']['client_id'],
				'client_secret' => @options['uaa']['client_secret']
			})
		end

		unless @auth_token.nil?
			headers = {
				'Authorization' => "Bearer #{@auth_token}",
				'Content-Type' => 'application/json',
				'Accept' => 'application/json'
			}
			uri = URI.parse("#{@options['contract']['offers_endpoint']}?#{format_url_params(params)}")
			http = Net::HTTP.new(uri.host, uri.port)
			request = Net::HTTP::Get.new(uri.request_uri, headers)
			response = http.request(request)
			offer_response = JSON.parse(response.body)
			puts offer_response
		end

		return contract_info
	end

	def save_sf_record(offer, contract_status)
		# Set fields
		offer.save
	end

end