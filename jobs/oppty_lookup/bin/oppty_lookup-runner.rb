require "#{ENV['RUNNER_PATH']}/lib/runner.rb"
require "../src/oppty_lookup.rb"

class OpptyLookupRunner < Runner

	def initialize
		super()
		init_options("../config/settings.yml")
		init_logger()
	end

	def run!
		begin
			OpptyLookup.new(@options, @logger).execute!
		rescue Exception => e
			@logger.fatal e.message
			@logger.fatal e.backtrace.inspect
		ensure
			@logger.close
		end
	end
end

OpptyLookupRunner.new.run!