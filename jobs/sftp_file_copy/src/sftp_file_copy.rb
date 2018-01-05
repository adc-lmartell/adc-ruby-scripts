require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require 'net/sftp'
require 'date'

class SftpFileCopy < Job

	def initialize(options, logger)
		super(options, logger)
	end

	def execute!

		Net::SFTP.start(@options['sftp']['pacific-union']['host'], @options['sftp']['pacific-union']['username'], :password => @options['sftp']['pacific-union']['password']) do |sftp|	

			@logger.info "connected to sftp"
			puts "connected to sftp"

			path = @options['sftp_path']
			local_path = @options['local_path']
			base_filename = ARGV[0]

			sftp.dir.foreach("/#{path}") do |file|
				if(file.name.match(/(#{base_filename})\_(#{Date.today.strftime('%Y%m%d')})\.(\w+)/)) then
					extension = $3
					download = sftp.download("/#{path}/#{file.name}", "/#{local_path}/#{base_filename}.#{extension}")
					download.wait
				end
			end
		end
	end
end
