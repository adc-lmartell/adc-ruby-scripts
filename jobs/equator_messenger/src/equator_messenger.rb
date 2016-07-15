require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require 'watir-webdriver'
require 'watir-webdriver/wait'
require 'headless'
require 'ntlm/smtp'
require 'date'

class EquatorMessenger < Job

	class NoClientLoginException < Exception 
	end

	def initialize(options, logger)
		super(options, logger)
		@messages = []
		@login_credentials = {
			"Bank of America": {
				:url => "https://vendors.equator.com",
				:username => "bac_auction@auction.com",
				:password => "Auction2014"
			},
			"Fannie Mae": {
				:url => "https://vendors.equator.com",
				:username => "",
				:password => ""
			},
			"Freddie Mac": {
				:url => "https://vendors.equator.com",
				:username => "",
				:password => ""
			}
		}
	end

	def execute!

		# Login to SFDC for the records that need processed
		@logger.info "Logging into Salesforce"

		begin
			restforce_client = get_restforce_client(@options['salesforce']['internal']['production'], true)
			client = restforce_client[:client]

			# Pull the new requests and any old error records for processing
			eqms = client.query("SELECT Id, Client__c, Loan_Number__c, Subject__c, Body__c, Agent__c, Asset_Manager__c, Sr_Asset_Manager__c, Status__c, Complete_Date__c, Error_Message__c FROM EQ_Message__c WHERE Status__c IN ('Requested', 'Error', 'Processing') AND RecordType.Name = 'Equator Messaging' ORDER BY CreatedDate DESC LIMIT 10")

			unless eqms.size == 0
				eqms.each do |eqm|
					@messages.push({
						:sf_record => eqm,
						:client => eqm.Client__c,
						:contact_agent => eqm.Agent__c,
						:contact_sr_am => eqm.Sr_Asset_Manager__c,
						:contact_am => eqm.Asset_Manager__c,
						:reo_number => eqm.Loan_Number__c, 
						:subject => eqm.Subject__c, 
						:body => eqm.Body__c
					})
					save_sf_record(eqm, "Processing", nil, nil)
				end
				upload_messages_to_equator(client)
			end

		rescue Exception => e
			@logger.error "Error: #{e}"
		end

		@logger.info "Successfully completed"
		# send_mail('EQ Messenger: Successful Run', 'Job ran successfully', @options['smtp'])
	end

	private

	def upload_messages_to_equator(client)
		logged_in = false

		# ----Uncomment when running on virtual machine----
		# headless = Headless.new
		# headless.start

		b = Watir::Browser.new
		# b.driver.manage.timeouts.implicit_wait = 10 #10 seconds

		@messages.each do |message|
			begin
				unless @login_credentials.has_key?(message[:client])
					throw NoClientLoginException.new("No login credentials for client '#{message[:client]}'")
				end

				unless logged_in 
					credentials = @login_credentials[message[:client]]

					b.goto credentials[:url]
					b.text_field(:name, 'enter_username').set credentials[:username]
					b.text_field(:name, 'enter_password').set credentials[:password]
					b.button(:name, 'btnLogin').click

					logged_in = true
				end

				# b.goto "https://vendors.equator.com/index.cfm?event=property.search&clearCookie=true"
				b.a(:text,'Properties').click
				b.a(:text,'Search Properties').wait_until_present
				b.a(:text,'Search Properties').click

				b.select_list(:name, 'property_SearchType').select "REO Number"
				b.text_field(:name, 'property_SearchText').set message[:reo_number]
				b.button(:name, 'btnSearch').click

				b.links(:href, /property\.viewEvents/).last.wait_until_present				
				uri = b.links(:href, /property\.viewEvents/).last.href

				b.goto "#{uri}"

				b.table(:id, 'propertyHeader').wait_until_present
				b.links(:text, 'Add Message').last.wait_until_present
				b.links(:text, 'Add Message').last.click

				b.select_list(:id, 'flag_note_alerts').wait_until_present


				if message[:contact_agent] then
					b.select_list(:id, 'flag_note_alerts').select(Regexp.new("^AGENT"))
				end

				if message[:contact_am] then
					b.select_list(:id, 'flag_note_alerts').select(Regexp.new("^ASSET MANAGER"))
				end

				if message[:contact_sr_am] then
					b.select_list(:id, 'flag_note_alerts').select(Regexp.new("^SR ASSET MANAGER"))
				end

				b.text_field(:name, 'title').set message[:subject]
				b.textarea(:name, 'note').set message[:body]

				b.button(:name => 'noteSubmit').click
				b.button(:name => 'noteSubmit').wait_while_present

				save_sf_record(message[:sf_record], "Complete", "#{Date.today.to_s}", nil)
			rescue Exception => e
				save_sf_record(message[:sf_record], "Error", nil, e)
			end
		end
		b.close
		# headless.destroy
	end

	def save_sf_record(eqm, status, complete_date, error_message)
		unless complete_date.nil?
			eqm.Complete_Date__c = complete_date
		end
		unless error_message.nil?
			eqm.Error_Message__c = error_message
		end
		eqm.Status__c = status
		eqm.save
	end

	def send_mail(subject, body, smtp_opts)
		mail_body = <<-EOS
		From: #{smtp_opts['from_addr']}
		To: #{smtp_opts['to_addr']}
		Cc: #{smtp_opts['cc_list']}
		Subject: #{subject}
		Content-Type: text/plain

		#{body}
		EOS

		smtp = Net::SMTP.new(smtp_opts['host'])
		smtp.start(smtp_opts['domain'], smtp_opts['username'], smtp_opts['password'], :ntlm) do |smtp|
		  smtp.send_mail(mail_body, smtp_opts['from_addr'], smtp_opts['to_addr'])
		end
	end
end