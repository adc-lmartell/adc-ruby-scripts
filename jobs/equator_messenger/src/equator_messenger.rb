require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require 'watir-webdriver'
require 'watir-webdriver/wait'
require 'net/sftp'
require 'ntlm/smtp'
require 'fileutils'
require 'csv'

class EquatorMessenger < Job

	def initialize(options, logger)
		super(options, logger)
		@process_map = {}
		@login_credentials = {
			:url => 'https://vendors.equator.com',
			:username => 'bac_auction@auction.com',
			:password => 'Auction2014'
		}
	end

	def execute!
		@logger.info "Logging into SFTP server"
		sftp = start_sftp_session(@options['sftp'])

		@logger.info "Push error/success files to SFTP if failed previously"
		push_sftp_files(sftp, @options['local'], @options['sftp'])

		@logger.info "Pull files to process from SFTP"
		pull_files_to_process(sftp, @options['local'], @options['sftp'])

		@logger.info "Processing files locally"
		process_files(sftp, @options['local'], @options['sftp'])

		@logger.info "Uploading messages to Equator"
		upload_messages_to_equator

		@logger.info "Creating error/success files"
		create_output_files(@options['local'])

		@logger.info "Logging into SFTP server"
		sftp = start_sftp_session(@options['sftp'])

		@logger.info "Pushing error/success files to SFTP"
		push_sftp_files(sftp, @options['local'], @options['sftp'])

		@logger.info "Removed processed files from SFTP dropbox"
		cleanup_sftp_files(sftp, @options['sftp'])

		@logger.info "Successfully completed"
		# send_mail('EQ Messenger: Successful Run', 'Job ran successfully', @options['smtp'])
	end

	private

	# Create a new SFTP session
	def start_sftp_session(options)
		Net::SFTP.start(options['host'], options['username'], { :port => (options['port'] || 22), :password => options['password'] });
	end

	# If there was an issue completing the previous run then attempt to move the temp files back to SFTP
	def push_sftp_files(sftp, local_opts, sftp_opts)
		unless Dir.entries("#{ENV['RUNNER_PATH']}/#{@options['local']['error_path']}").select {|f| f =~ /^.+\.csv$/}.empty?
			move_files_to_sftp(sftp, "#{ENV['RUNNER_PATH']}/#{local_opts['error_path']}", "#{sftp_opts['error_path']}")
		end

		unless Dir.entries("#{ENV['RUNNER_PATH']}/#{@options['local']['completed_path']}").select {|f| f =~ /^.+\.csv$/}.empty?
			move_files_to_sftp(sftp, "#{ENV['RUNNER_PATH']}/#{local_opts['completed_path']}", "#{sftp_opts['completed_path']}")
		end
	end

	# Move a directory of files from the local system to the SFTP system
	def move_files_to_sftp(sftp, local_folder, sftp_folder)
		Dir.entries(local_folder).select {|f| f =~ /^.+\.csv/}.each do |f|
			begin
				sftp.upload!("#{local_folder}/#{f}", "#{sftp_folder}/#{f}")
				File.unlink("#{local_folder}/#{f}")
			rescue Exception => e
				@logger.error "Error moving file to SFTP: #{e}"
			end
		end
	end

	# Grab all the temporary (or processing files) from SFTP so they can be processed locally
	def pull_files_to_process(sftp, local_opts, sftp_opts)
		sftp.dir.foreach("#{sftp_opts['drop_path']}") do |f|
			if f.name =~ /^.+\.csv$/ then
				sftp.download!("#{sftp_opts['drop_path']}/#{f.name}", "#{ENV['RUNNER_PATH']}/#{local_opts['drop_path']}/#{f.name}")
			end
		end

		sftp.dir.foreach("#{sftp_opts['offer_path']}") do |f|
			if f.name =~ /^[^\.].+$/ then 
				sftp.download!("#{sftp_opts['offer_path']}/#{f.name}", "#{ENV['RUNNER_PATH']}/#{local_opts['offer_path']}/#{f.name}")
			end
		end

		sftp.dir.foreach("#{sftp_opts['template_path']}") do |f|
			if f.name =~ /^[^\.].+$/ then 
				sftp.download!("#{sftp_opts['template_path']}/#{f.name}", "#{ENV['RUNNER_PATH']}/#{local_opts['template_path']}/#{f.name}")
			end
		end
	end

	# Process all the files that were pulled down locally
	def process_files(sftp, local_opts, sftp_opts)
		required_headers = ["Agent", "Sr. Asset Manager", "Asset Manager", "Loan No", "Subject", "Body"]

		@process_map[:messages] = {}
		@process_map[:csv_list] = {}

		Dir.entries("#{ENV['RUNNER_PATH']}/#{local_opts['drop_path']}").select {|f| f =~ /^.+\.csv/}.each do |f|
			begin
				@process_map[:messages][f] = []
				@process_map[:csv_list][f] = []

				header_map = {}
				index = 0

				CSV.foreach("#{ENV['RUNNER_PATH']}/#{local_opts['drop_path']}/#{f}") do |row|
					if index == 0 then
						row.each_with_index { |header, index| header_map[header] = index }
						@process_map[:csv_list][f].push(row + ["Status","Message"])
					else
						if (required_headers - header_map.keys).empty? then
							@process_map[:messages][f].push({
								:contact_agent => !row[header_map["Agent"]].nil?,
								:contact_sr_am => !row[header_map["Sr. Asset Manager"]].nil?,
								:contact_am => !row[header_map["Asset Manager"]].nil?,
								:reo_number => row[header_map["Loan No"]], 
								:subject => row[header_map["Subject"]], 
								:body => row[header_map["Body"]]
							})
							@process_map[:csv_list][f].push(row)
						else
							@process_map[:csv_list][f].push(row + ["Error", "Cannot process file because required headers missing: #{(required_headers - header_map.keys).join(',')}"])
						end
					end
					index += 1
				end
			rescue Exception => e
				@logger.error "Error parsing file #{f}: #{e}"
				FileUtils.mv("#{ENV['RUNNER_PATH']}/#{local_opts['drop_path']}/#{f}", "#{ENV['RUNNER_PATH']}/#{local_opts['error_path']}/#{f}")
			end
			File.unlink("#{ENV['RUNNER_PATH']}/#{local_opts['drop_path']}/#{f}")
		end
	end

	def upload_messages_to_equator()
		unless @process_map[:messages].empty?
			b = Watir::Browser.new

			@process_map[:messages].each do |filename, messages|
				unless messages.empty?
					b.goto @login_credentials[:url]

					if b.links(:text, 'Search Properties').size == 0
						b.text_field(:name, 'enter_username').set @login_credentials[:username]
						b.text_field(:name, 'enter_password').set @login_credentials[:password]
						b.button(:name, 'btnLogin').click
					end

					messages.each_with_index do |message, index|
						begin
							b.goto "https://vendors.equator.com/index.cfm?event=property.search&clearCookie=true"
							b.select_list(:name, 'property_SearchType').select "REO Number"
							b.text_field(:name, 'property_SearchText').set message[:reo_number]
							b.button(:name, 'btnSearch').click

							b.links(:href, /property\.viewEvents/).last.click

							b.links(:text, 'Add Message').last.wait_until_present
							b.links(:text, 'Add Message').last.click

							b.select_list(:id, 'flag_note_alerts').wait_until_present

							if message[:contact_agent] then
								b.select_list(:id, 'flag_note_alerts').select(Regexp.new("^AGENT"))
								Watir::Wait.until { b.select_list(:id, 'flag_note_alerts').include?(Regexp.new("^AGENT")) }
							end

							if message[:contact_am] then
								b.select_list(:id, 'flag_note_alerts').select(Regexp.new("^ASSET MANAGER"))
								Watir::Wait.until { b.select_list(:id, 'flag_note_alerts').include?(Regexp.new("^ASSET MANAGER")) }
							end

							if message[:contact_sr_am] then
								b.select_list(:id, 'flag_note_alerts').select(Regexp.new("^SR ASSET MANAGER"))
								Watir::Wait.until { b.select_list(:id, 'flag_note_alerts').include?(Regexp.new("^SR ASSET MANAGER")) }
							end

							b.text_field(:name, 'title').set message[:subject]
							b.textarea(:name, 'note').set message[:body]

							b.button(:name => 'noteSubmit').click
							b.button(:name => 'noteSubmit').wait_while_present

							@process_map[:csv_list][filename][index+1].push(["Success", ""]).flatten!
							@logger.info "#{message[:reo_number]},Success"
						rescue Exception => e
							@process_map[:csv_list][filename][index+1].push(["Error", e.message]).flatten!
							@logger.info "#{message[:reo_number]},Error,#{e.message}"
						end
					end
				end
			end
			b.close
		end
	end

	def create_output_files(local_opts)
		unless @process_map[:csv_list].empty?
			@process_map[:csv_list].each do |filename, rows|
				if rows.size > 1 then
					
					success_rows = rows.select { |row| row.last != 'Message' && row.last.size == 0 }
					unless success_rows.empty?
						CSV.open("#{ENV['RUNNER_PATH']}/#{local_opts['completed_path']}/#{filename}", "wb") do |csv|
							csv << rows[0]
							success_rows.each { |row| csv << row }
						end
					end

					error_rows = rows.select { |row| row.last != 'Message' && row.last.size != 0 }
					unless error_rows.empty?
						CSV.open("#{ENV['RUNNER_PATH']}/#{local_opts['error_path']}/#{filename}", "wb") do |csv|
							csv << rows[0]
							error_rows.each { |row| csv << row }
						end
					end
				end
			end
		end
	end

	def cleanup_sftp_files(sftp, sftp_opts)
		@process_map[:csv_list].keys.each do |filename|
			begin
				sftp.remove!("#{sftp_opts['drop_path']}/#{filename}")
			rescue Exception => e
				@logger.warn "SFTP file not in dropbox when removing: #{filename}"
			end
		end
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