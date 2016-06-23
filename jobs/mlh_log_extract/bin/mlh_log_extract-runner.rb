require "#{ENV['RUNNER_PATH']}/lib/runner.rb"
require "../src/mlh_log_extract.rb"

class MLHExtractRunner < Runner

	def initialize
		super()
		init_options("../config/settings.yml")
		init_logger()
	end

	def run!
		begin
			MLHExtract.new(@options, @logger).execute!
		rescue Exception => e
			@logger.fatal e.message
			@logger.fatal e.backtrace.inspect
		ensure
			@logger.close
		end
	end
end

MLHExtractRunner.new.run!