require "#{ENV['RUNNER_PATH']}/lib/runner.rb"
require "../src/oppty_lookup-bulk.rb"

class OpptyLookupRunnerBulk < Runner

	def initialize
		super()
		init_options("../config/settings.yml")
		init_logger()
	end

	def run!
		begin
			OpptyLookupBulk.new(@options, @logger).execute!
		rescue Exception => e
			@logger.fatal e.message
			@logger.fatal e.backtrace.inspect
		ensure
			@logger.close
		end
	end
end

OpptyLookupRunnerBulk.new.run!