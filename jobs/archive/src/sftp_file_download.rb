require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require 'net/sftp'
require 'date'

class SftpFileCopy < Job

	def initialize(options, logger)
		super(options, logger)
	end

	def execute!

		sftp_host  		= ARGV[0]
		sftp_user 		= ARGV[1]
		sftp_pwd 			= ARGV[2]
		remote_path 	= ARGV[3]
		base_filename = ARGV[4]
		time_frmt  		= ARGV[5]
		local_path 		= ARGV[6]

		Net::SFTP.start(sftp_host, sftp_user, :password => sftp_pwd) do |sftp|	
			timestamp = Date.today.strftime("#{time_frmt}")

			sftp.dir.foreach("/#{remote_path}") do |file|
				if(file.name.match(/(#{base_filename})\_(#{timestamp})\d*\.(\w+)/)) then
					download = sftp.download("#{file.name}", "#{local_path}")
					download.wait
				end
			end
		end
	end
end