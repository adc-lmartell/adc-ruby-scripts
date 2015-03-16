require "#{ENV['RUNNER_PATH']}/lib/runner.rb"
require "../src/data_tape_loader.rb"

class DataTapeLoaderRunner < Runner

	def initialize
		super()
		init_options("../config/settings.yml")
		init_logger()
	end

	def run!
		begin
			DataTapeLoader.new(@options, @logger).execute!
		rescue Exception => e
			@logger.fatal e.message
			@logger.fatal e.backtrace.inspect
		ensure
			@logger.close
		end
	end
end

DataTapeLoaderRunner.new.run!