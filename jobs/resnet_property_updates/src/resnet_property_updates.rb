require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require 'watir-webdriver'
require 'watir-webdriver/wait'
# require 'headless'
require 'ntlm/smtp'
require 'date'

class ResnetPropertyUpdates < Job

	def initialize(options, logger)
		super(options, logger)

		@properties = {}
	end

	def execute!

		# Login to SFDC for the records that need processed
		@logger.info "Logging into Salesforce"

		begin
			restforce_client = get_restforce_client(@options['salesforce']['internal']['development'], true)
			client = restforce_client[:client]

			# Pull the new requests and any old error records for processing
			props = client.query("SELECT Id, Loan_Number__c, Outsourcer__c, Auction_Start_Date__c, Auction_End_Date__c, Finance__c, Highest_Bid__c, Link__c, Reserve__c, Runs__c, Web_Hits__c FROM EQ_Message__c WHERE Status__c IN ('Requested', 'Error', 'Processing') AND Target__c = \'ResNet\' ORDER BY CreatedDate DESC LIMIT 10")

			unless props.size == 0
				props.each do |prop|
					outsourcer = ""

					if !prop.Outsourcer__c.nil?	

						if prop.Outsourcer__c == "LRES" then
							outsourcer = "les_res"
						elsif prop.Outsourcer__c == "Champion" then
							outsourcer = "champion"
						elsif prop.Outsourcer__c == "Carrington Property Services, LLC" then
							outsourcer = "carrington"
						elsif prop.Outsourcer__c == "Single Source Property Solutions" then
							outsourcer = "single_source"
						end

						if !@properties.has_key?(outsourcer) then
							@properties[outsourcer] = []
						end

						@properties[outsourcer].push({
							:sf_record => prop,
							:loan_num => prop.Loan_Number__c,
							:outsourcer => prop.Outsourcer__c,
							:start_date => format_date(prop.Auction_Start_Date__c),
							:end_date => format_date(prop.Auction_End_Date__c), 
							:finance => (prop.Finance__c.downcase == "yes" || prop.Finance__c.downcase == "no") ? prop.Finance__c : "",
							:high_bid => prop.Highest_Bid__c,
							:link => prop.Link__c,
							:reserve => prop.Reserve__c,
							:run => prop.Runs__c,
							:web_hits => format_int(prop.Web_Hits__c)
						})
						save_sf_record(prop, "Processing", nil, nil)
					else
						save_sf_record(prop, "Error", nil, "Outsource not provided.")
					end
				end

				update_assets_in_resnet()
			end

		rescue Exception => e
			puts e
			@logger.error "Error with Salesforce: #{e}"
		end

		@logger.info "Successfully completed"
		# send_mail('EQ Messenger: Successful Run', 'Job ran successfully', @options['smtp'])
	end

	private

	def update_assets_in_resnet()

		# headless = Headless.new
		# headless.start

		@properties.each do |outsourcer, properties|

			puts outsourcer

			login = @options['resnet'][outsourcer]['username']
			pwd = @options['resnet'][outsourcer]['password']

			b = Watir::Browser.new

			# #direct firefox to URL
			b.goto @options['resnet'][outsourcer]['url']

			#log into resnet
			if b.button(:value, 'Login').exists?
				b.text_field(:name, 'amLoginId').set login
				b.text_field(:name, 'amIdentity').set pwd
				b.button(:value, 'Login').click
			end

			#wait until the global property search is present DO I NEED THIS
			# b.text_field(:id, 'globalPropertySearch').wait_until_present
			b.link(:text, 'Properties').wait_until_present
			
			properties.each do |property|
				begin
					loan = property[:loan_num]	

					#select the properties tab
					b.link(:text, 'Properties').click

					#wait for the page to render
					b.text_field(:name,'pfLoan').wait_until_present

					#set the loan number and search
					b.text_field(:name,'pfLoan').set loan
					b.input(:id,'btnSearchProp').click

					#wait for search to complete
					b.element(:css => '#resultsHere table tr:nth-child(2) td:first-child a').wait_until_present

					#click searched property
					b.element(:css => '#resultsHere table tr:nth-child(2) td:first-child a').click

					#wait for property to load then click listing
					b.li(:id,'listing').wait_until_present
					b.li(:id,'listing').click

					#update property details
					b.li(:id, 'panelCustomFields').wait_until_present
					if !property[:start_date].nil?
						b.text_field(:id, 'cf_AuctionStartDate').set property[:start_date]
					end

					if !property[:end_date].nil?
						b.text_field(:id, 'cf_AuctionEndDate').set property[:end_date]
					end

					if !property[:finance].nil?
						finance = property[:finance]
						id = (outsourcer == 'carrington') ? 'cf_AuctionFinance' : 'cf_REDCFinance'
						b.select_list(:id, id).select(Regexp.new("^#{finance}"))
					end

					if !property[:run].nil?
						runs = property[:run]
						if !runs.nil? && runs.to_s.match(/(\d+)\.0/) then
							run_num = runs.to_s.match(/(\d+)\.0/)[1]
							
							if run_num.to_i > 10 then
								run_num = "10"
							end

							b.select_list(:id, 'cf_AuctionRun').select(Regexp.new("^#{run_num}"))
						end
					end
					
					if !property[:web_hits].nil?
						b.text_field(:id, 'cf_WebHits').set property[:web_hits]
					end

					if !property[:high_bid].nil?
						b.text_field(:id, 'cf_HighestBid').set property[:high_bid]
					end

					if !property[:reserve].nil?
						b.text_field(:id, 'cf_ReserveAmount').set property[:reserve]
					end
					
					if !property[:link].nil?
						b.textarea(:id, 'cf_LinkToPropertyonAuctioncom').set property[:link]
					end

					b.button(:id, "btnUpdateCustomFields").click
					save_sf_record(property[:sf_record], "Complete", "#{Date.today.to_s}", nil)

				rescue Exception => e
					@logger.info e
					save_sf_record(property[:sf_record], "Error", nil, e)
				end
			end

			b.close
		end
	end


	def save_sf_record(prop, status, complete_date, error_message)
		unless complete_date.nil?
			prop.Complete_Date__c = complete_date
		end
		unless error_message.nil?
			prop.Error_Message__c = error_message
		end
		prop.Status__c = status
		prop.save
	end

	def format_date(date)
		if !date.match(/(\d+)\-(\d+)\-(\d+)/).nil? then
			year = "#{$1}".length == 2 ? "20#{$1}" : "#{$1}"
			month = "#{$2}"
			day = "#{$3}"
			date = "#{month}/#{day}/#{year}"
		end

		return date
	end

	def format_int(num)
		if num.to_s.match(/(\d+)\.\d+/) then
			num = "#{$1}"
		end

		return num.to_i
	end

	# def send_mail(subject, body, smtp_opts)
	# 	mail_body = <<-EOS
	# 	From: #{smtp_opts['from_addr']}
	# 	To: #{smtp_opts['to_addr']}
	# 	Cc: #{smtp_opts['cc_list']}
	# 	Subject: #{subject}
	# 	Content-Type: text/plain

	# 	#{body}
	# 	EOS

	# 	smtp = Net::SMTP.new(smtp_opts['host'])
	# 	smtp.start(smtp_opts['domain'], smtp_opts['username'], smtp_opts['password'], :ntlm) do |smtp|
	# 	  smtp.send_mail(mail_body, smtp_opts['from_addr'], smtp_opts['to_addr'])
	# 	end
	# end
end