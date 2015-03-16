require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require 'watir-webdriver'
require 'watir-webdriver/wait'
require 'net/sftp'
require 'csv'

class EquatorMessenger < Job

	def initialize(options, logger)
		super(options, logger)
		@process_map = {}
	end

	def execute!
		@logger.info "Logging into SFTP server"
		sftp = start_sftp_session(@options['sftp'])

		@logger.info "Cleanup of temporary files if necessary"
		cleanup_temp_files(sftp)

		@logger.info "Pull files to process from SFTP"
		pull_files_to_process(sftp, @options['local'], @options['sftp'])

		@logger.info "Processing files locally"
		process_files(sftp, @options['local'], @options['sftp'])

		@logger.info "Successfully completed"
	end

	private

	# Process all the files that were pulled down locally
	def process_files(sftp, local_opts, sftp_opts)

		Dir.entries("#{ENV['RUNNER_PATH']}/#{local_opts['drop_path']}").select {|f| f =~ /^.+\.csv/} do |f|

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

	# If there was an issue completing the previous run then attempt to move the temp files back to SFTP
	def cleanup_temp_files(sftp)
		unless Dir.entries("#{ENV['RUNNER_PATH']}/#{@options['local']['error_path']}").select {|f| f =~ /^.+\.csv$/}.empty?
			move_files_to_sftp(sftp, "#{ENV['RUNNER_PATH']}/#{@options['local']['error_path']}", "#{@options['sftp']['error_path']}")
		end

		unless Dir.entries("#{ENV['RUNNER_PATH']}/#{@options['local']['completed_path']}").select {|f| f =~ /^.+\.csv$/}.empty?
			move_files_to_sftp(sftp, "#{ENV['RUNNER_PATH']}/#{@options['local']['completed_path']}", "#{@options['sftp']['completed_path']}")
		end
	end

	# Create a new SFTP session
	def start_sftp_session(options)
		Net::SFTP.start(options['host'], options['username'], { :port => (options['port'] || 22), :password => options['password'] });
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

	def send_email(body)

	end

	def fetch_csv_from_sftp()
		home_path = "#{ENV['RUNNER_PATH']}/#{@options['sftp']['home_path']}"

		@logger.info "Pulling CSV files from SFTP"

		@process_map[:rows] = []

		Dir.entries(home_path + '/' + @options['sftp']['drop_path']).each do |file|
			file_path = home_path + '/' + @options['sftp']['drop_path'] + '/' + file
			completed_path = home_path + '/' + @options['sftp']['completed_path'] + '/' + file
			error_path = home_path + '/' + @options['sftp']['error_path'] + '/' + file

			if file =~ /^.+\.csv$/
				@logger.info "Parsing file: #{file}"

				begin
					@process_map[:rows] << CSV.read(file_path)
					File.rename(file_path, completed_path)
				rescue Exception => e
					@logger.error "CSV Read Error: #{e}"
					File.rename(file_path, error_path);
				end
			end
		end
	end

	def reorganize_rows()
		unless @process_map[:rows].empty?
			columns = ['REO #', 'Subject', 'Body'];

			@logger.info "Reorganizing rows into Equator messages"

			@process_map[:messages] = []

			@process_map[:rows].each do |csv|
				column_map = {}

				csv.each_with_index do |row, row_index|
					message = {}

					if row_index == 0 then
						row.each_with_index do |column, col_index|
							if columns.include?(column) then
								column_map[col_index] = column
							end
						end
					else 
						row.each_with_index do |column, col_index|
							message[column_map[col_index]] = column
						end
					end
					@process_map[:messages] << message unless row_index == 0
				end
			end
		end
	end

	def upload_messages_to_equator()
		unless @process_map[:rows].empty? || @process_map[:messages].empty?
			b = Watir::Browser.new

			@logger.info "Uploading messages to Equator"

			b.goto @options["equator"]["url"]
			b.text_field(:name => 'enter_username').set @options["equator"]["username"]
			b.text_field(:name => 'enter_password').set @options["equator"]["password"]
			b.button(:name => 'btnLogin').click

			@process_map[:messages].each do |message|
				b.goto "https://vendors.equator.com/index.cfm?event=property.search&clearCookie=true"
				b.select_list(:name => 'property_SearchType').select "REO Number"
				b.text_field(:name => 'property_SearchText').set message["REO #"]
				b.button(:name => 'btnSearch').click

				b.links(:href => /property\.viewEvents/).last.click

				b.links(:href => '#ui-tabs-2').last.wait_until_present
				b.links(:href => '#ui-tabs-2').last.click

				b.links(:href => '#ui-tabs-6').last.wait_until_present
				b.links(:href => '#ui-tabs-6').last.click

				b.select_list(:id => 'flag_note_alerts').wait_until_present
				b.select_list(:id => 'flag_note_alerts').select "AUCTION COMPANY - AUCTION.COM BAC"
				b.text_field(:name => 'title').set message["Subject"]
				b.textarea(:name => 'note').set message["Body"]

				b.button(:name => 'noteSubmit').click
				b.button(:name => 'noteSubmit').wait_while_present
			end
		end
	end

end