require "#{ENV['RUNNER_PATH']}/lib/runner.rb"
require "../src/noncwcot_file_formatter.rb"

class NonCWCOTPostFileFormatterRunner < Runner

	def initialize
		super()
		init_options("../config/settings.yml")
		init_logger()
	end

	def run!
		begin
			NonCWCOTPostFileFormatter.new(@options, @logger).execute!
		rescue Exception => e
			@logger.fatal e.message
			@logger.fatal e.backtrace.inspect
		ensure
			@logger.close
		end
	end
end

NonCWCOTPostFileFormatterRunner.new.run!