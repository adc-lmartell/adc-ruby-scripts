require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require 'watir-webdriver'
require 'watir-webdriver/wait'
require 'csv'

class EquatorMessenger < Job

	def initialize(options, logger)
		super(options, logger)
		@process_map = {}
	end

	def execute!
		fetch_csv_from_sftp
		reorganize_rows
		upload_messages_to_equator

		@logger.info "Successfully completed"
	end

	private

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