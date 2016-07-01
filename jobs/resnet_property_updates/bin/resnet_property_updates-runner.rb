require "#{ENV['RUNNER_PATH']}/lib/runner.rb"
require "../src/resnet_property_updates.rb"

class ResnetPropertyUpdatesRunner < Runner

	def initialize
		super()
		init_options("../config/settings.yml")
		init_logger()
	end

	def run!
		begin
			ResnetPropertyUpdates.new(@options, @logger).execute!
		rescue Exception => e
			@logger.fatal e.message
			@logger.fatal e.backtrace.inspect
		ensure
			@logger.close
		end
	end
end

ResnetPropertyUpdatesRunner.new.run!