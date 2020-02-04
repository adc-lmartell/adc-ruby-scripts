require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

require "#{ENV['RUNNER_PATH']}/lib/job.rb"

# require 'watir'
# require 'watir-webdriver'
# require 'watir-webdriver/wait'
# require 'headless'

class NoClientLoginException < Exception 
end

class EquatorMessenger < Job

	def initialize(options, logger)
		super(options, logger)
		@messages = []
		@login_credentials = {
			"Bank of America" => {
				:url => @options['equator']['bac']['url'],
				:username => @options['equator']['bac']['username'],
				:password => @options['equator']['bac']['password']
			}
		}
	end

	def execute!

		# Login to SFDC for the records that need processed
		@logger.info "Logging into Salesforce"

		begin
			restforce_client = get_restforce_client(@options['salesforce']['external']['production'], true)
			client = restforce_client[:client]

			# Pull the new requests and any old error records for processing
			eqms = client.query("SELECT Id, Client__c, LN_UUID__r.loan_no__c, Subject__c, Body__c, Agent__c, Asset_Manager__c, Sr_Asset_Manager__c, Closing_Officer__c, Sr_Closing_Officer__c, Status__c, Complete_Date__c, Error_Message__c FROM External_Update__c WHERE Status__c IN ('Requested', 'Error', 'Processing') AND RecordType.Name = 'Equator Messaging' AND LN_UUID__c != null ORDER BY CreatedDate DESC LIMIT 25")

			unless eqms.size == 0	
				eqms.each do |eqm|
					unless eqm.LN_UUID__r.loan_no__c.nil?
						@messages.push({
							:sf_record => eqm,
							:client => eqm.Client__c,
							:contact_agent => eqm.Agent__c,
							:contact_sr_am => eqm.Sr_Asset_Manager__c,
							:contact_am => eqm.Asset_Manager__c,
							:contact_sr_co => eqm.Sr_Closing_Officer__c,
							:contact_co => eqm.Closing_Officer__c,
							:reo_number => eqm.LN_UUID__r.loan_no__c, 
							:subject => eqm.Subject__c, 
							:body => eqm.Body__c
						})
						save_sf_record(eqm, "Processing", nil, nil)
					end
				end
				upload_messages_to_equator(client) unless @messages.empty?
			end

		rescue Exception => e
			@logger.error "Error: #{e}"
		end

		@logger.info "Successfully completed"
	end

	private

	def upload_messages_to_equator(client)
		logged_in = false

		# ----Uncomment when running on virtual machine----
		headless = Headless.new
		headless.start

		b = Watir::Browser.new :chrome
		# b.driver.manage.timeouts.implicit_wait = 10 #10 seconds

		@messages.each do |message|
			begin
				unless @login_credentials.has_key?(message[:client]) 
					raise NoClientLoginException.new("No login credentials for client '#{message[:client]}'")
				end

				if logged_in == false
					credentials = @login_credentials[message[:client]]

					# Goto EQ login page
					b.goto credentials[:url]

					# Populate login form
					b.text_field({ name: 'enter_username' }).set credentials[:username]
					b.text_field({ name: 'enter_password' }).set credentials[:password]

					# Click login button
					b.button({ name: 'btnLogin' }).click

					logged_in = true
				end

				# Navigate to search page
				b.goto "https://vendors.equator.com/index.cfm?event=property.search&clearCookie=true"
				
				# Deprecated UX flow
				# b.a({ text: 'Properties' }).click
				# b.a({ text: 'Search Properties' }).wait_until(&:present?)
				# b.a({ text: 'Search Properties' }).click

				# Update search filters and click Search
				b.select_list({ name: 'property_SearchType' }).select "REO Number"
				b.text_field({ name: 'property_SearchText' }).set message[:reo_number]
				b.button({ name: 'btnSearch' }).click

				# Find property detail page from results 
				b.links({ href: /event=property.viewEvents/ }).last.wait_until(&:present?)
				uri = b.links({ href: /event=property.viewEvents/ }).last.href

				# Goto the property detail page
				b.goto "#{uri}"

				# Click on Add Message link
				b.table({ id: 'propertyHeader' }).wait_until(&:present?)
				b.links({ text: 'Add Message' }).last.wait_until(&:present?)
				b.links({ text: 'Add Message' }).last.click

				b.select_list({ id: 'flag_note_alerts' }).wait_until(&:present?)

				if message[:contact_agent] then
					b.select_list({ id: 'flag_note_alerts' }).select(Regexp.new("^AGENT"))
				end

				if message[:contact_am] then
					b.select_list({ id: 'flag_note_alerts' }).select(Regexp.new("^ASSET MANAGER"))
				end

				if message[:contact_sr_am] then
					b.select_list({ id: 'flag_note_alerts' }).select(Regexp.new("^SR ASSET MANAGER"))
				end

				if message[:contact_co] then
					b.select_list({ id: 'flag_note_alerts' }).select(Regexp.new("^CLOSING OFFICER"))
				end

				if message[:contact_sr_co] then
					b.select_list({ id: 'flag_note_alerts' }).select(Regexp.new("^SR CLOSING OFFICER"))
				end

				b.text_field({ name: 'title' }).set message[:subject]
				b.textarea({ name: 'note' }).set message[:body]

				b.button({ name: 'noteSubmit' }).click
				b.button({ name: 'noteSubmit' }).wait_while(&:present?)

				save_sf_record(message[:sf_record], "Complete", "#{Date.today.to_s}", nil)
			rescue Exception => e
				save_sf_record(message[:sf_record], "Error", nil, e)
			end
		end
		b.close
		headless.destroy
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

end
