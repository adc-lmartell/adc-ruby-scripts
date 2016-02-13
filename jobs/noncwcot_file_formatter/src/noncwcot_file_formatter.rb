 require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require "#{ENV['RUNNER_PATH']}/lib/logger.rb"
require 'net/sftp'

class NonCWCOTFileFormatter < Job

	def initialize(options, logger)
		super(options, logger)		
	end

	def execute!
		
	end
	
end