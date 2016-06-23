require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require "#{ENV['RUNNER_PATH']}/lib/logger.rb"
require 'net/sftp'

class MLHExtract < Job
	def initialize(options, logger)
		super(options, logger)
	end

	def execute!

		Net::SFTP.start(@options['sftp']['closing']['host'], @options['sftp']['closing']['username'], :password => @options['sftp']['closing']['password']) do |sftp|	
	
		end
	end
end