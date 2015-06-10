require "#{ENV['RUNNER_PATH']}/lib/runner.rb"
require "../src/ptr_uploads.rb"

class PTRUploadsRunner < Runner

	def initialize
		super()
		init_options("../config/settings.yml")
		init_logger()
	end

	def run!
		begin
			PTRUploads.new(@options, @logger).execute!
		rescue Exception => e
			@logger.fatal e.message
			@logger.fatal e.backtrace.inspect
		ensure
			@logger.close
		end
	end
end

PTRUploadsRunner.new.run!