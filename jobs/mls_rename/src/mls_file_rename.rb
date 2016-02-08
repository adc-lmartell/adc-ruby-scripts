require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require 'net/sftp'
require 'date'

class MlsFileRename < Job

	def initialize(options, logger)
		super(options, logger)
	end

	def execute!

		Net::SFTP.start(@options['sftp']['cwcot']['host'], @options['sftp']['cwcot']['username'], :password => @options['sftp']['cwcot']['password']) do |sftp|	

			@logger.info "connected to sftp"

			sftp.dir.foreach("/MLS/dropbox") do |file|
				if file.name =~ /^mls_agent_updates\.csv$/ then	
					sftp.rename("/MLS/dropbox/mls_agent_updates.csv","/MLS/archive/mls_agent_updates-#{Date.today.to_s}.csv")
					@logger.info "file renamed successfully"
				end
			end
		end
	end
end