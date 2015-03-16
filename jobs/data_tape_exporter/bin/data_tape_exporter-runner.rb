require "#{ENV['RUNNER_PATH']}/lib/runner.rb"
require "../src/data_tape_exporter.rb"

class DataTapeExporterRunner < Runner

	def initialize
		super()
		init_options("../config/settings.yml")
		init_logger()
	end

	def run!
		begin
			DataTapeExporter.new(@options, @logger).execute!
		rescue Exception => e
			@logger.fatal e.message
			@logger.fatal e.backtrace.inspect
		ensure
			@logger.close
		end
	end
end

DataTapeExporterRunner.new.run!