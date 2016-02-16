require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require "#{ENV['RUNNER_PATH']}/lib/logger.rb"
require 'net/sftp'
require 'csv'

class NonCWCOTPostFileFormatter < Job

	def initialize(options, logger)
		super(options, logger)		
	end

	def execute!
		
	end
	
	private


end