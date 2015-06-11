require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require "#{ENV['RUNNER_PATH']}/lib/logger.rb"
require 'date'
require 'json'
# require 'salesforce_bulk_api'

class OpptyLookup < Job
	def initialize(options, logger)
		super(options, logger)
	end

	def execute!

		@logger.info "Logging into Salesforce"

		# Restforce.log = true
		restforce_client = get_restforce_client(@options['salesforce']['external']['production'], true)
		client = restforce_client[:client]		

		@logger.info "Login successful"

		assets_to_aoas = {}
		aoas_for_update = []

		#fetch all cwcot aoas within the last 60 days that are missing an Opportunity lookup organize by Asset Id to Aoas
		aoas = client.query("Select Id, Opportunity__c, Assets__c, Assets__r.Property_Street__c, Assets__r.Property_City__c, Assets__r.Property_State__c, Assets__r.Property_Zip_Postal_Code__c, Assets__r.Occupancy_Status__c, Assets__r.Home_Square_Footage__c, Assets__r.Bedrooms__c, Assets__r.Property_Type__c, Auction_Campaign__c, MLH_Loan_Number__c, MLH_Seller_Code__c, MLH_Pool_Number__c, MLH_Product_Type__c, Seller_Name__c From Auction_Opportunity_Assignment__c Where CreatedDate = LAST_N_DAYS:60 And Line_of_Business__c = 'Residential' And MLH_Seller_Code__c <> 'TST' And Opportunity__c = null AND (NOT MLH_Property_Address__c LIKE '%TEST%')")		
		aoas.each do |aoa|
			assets_to_aoas[aoa.Assets__c] = [] if !assets_to_aoas.has_key?(aoa.Assets__c)
			assets_to_aoas[aoa.Assets__c] << aoa 
		end

		#instantiate the bulk api client to perform mass updates on Opportunity and AOAs
		# opps_for_insert = [];
		# aoas_for_update = [];
		# salesforce = SalesforceBulkApi::Api.new(client)		

		assets_to_aoas.keys.each do |asset_id|

			#collect opportunities related to the asset id
			opps = client.query("Select Id, SF_Integration_ID__c, Asset__c FROM Opportunity WHERE Asset__c = '#{asset_id}' ORDER BY CreatedDate DESC")

			parent_opp_Id = ''

			#if the list of opportunities came back populated set the lookup to the most current or the record with the SF Integration ID populated
			i = 0
			opps.each do |opp|			
				parent_opp_Id = opp.Id if i == 0
				parent_opp_Id = opp.Id if !opp.SF_Integration_ID__c.nil?
				i += 1
			end

			#if no opportunties were returned create a new opportunity with data from the aoa and generate the lookup
			if parent_opp_Id.length == 0 then
				aoa = assets_to_aoas[asset_id][0]

				opportunity_fields = {
					"Name" => 'Dummy Opp', 
					"CloseDate" => Date.today.to_s, 
					"StageName" => 'Stage 4. Pre-Auction', 
					"Asset__c" => asset_id, 
					"Product_Type__c" => 'REO', 
					"Property_Street__c" => aoa.Assets__r.Property_Street__c, 
					"Property_State__c" => aoa.Assets__r.Property_State__c, 
					"Property_City__c" => aoa.Assets__r.Property_City__c, 
					"Property_Zip_Postal_Code__c" => aoa.Assets__r.Property_Zip_Postal_Code__c, 
					"Occupancy__c" => aoa.Assets__r.Occupancy_Status__c, 
					"Square_Feet__c" => aoa.Assets__r.Home_Square_Footage__c, 
					"Bedrooms__c" => aoa.Assets__r.Bedrooms__c, 
					"Loan_Number__c" => aoa.MLH_Loan_Number__c, 
					"Most_Recent_Auction__c" => aoa.Auction_Campaign__c,
					"MLH_Seller_Code__c" => aoa.MLH_Seller_Code__c
				}

				# opps_for_insert.push(opportunity);
				opportunity_json = JSON.generate(opportunity_fields)
				parent_opp_Id = client.create('Opportunity', opportunity_json)				
			end 

			puts parent_opp_Id

			#set the opportunity lookup on aoa and update
			if parent_opp_Id.length > 0 then
				assets_to_aoas[asset_id].each do |aoa|
					client.update('Auction_Opportunity_Assignment__c', Id: aoa.Id, Opportunity__c: parent_opp_Id)
				end
			end			
		end

		# puts opps_for_insert;
		# result = salesforce.create("Opportunity", opps_for_insert)
		# puts "result is: #{result.inspect}"
	end
end