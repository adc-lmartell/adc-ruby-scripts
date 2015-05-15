require "#{ENV['RUNNER_PATH']}/lib/runner.rb"
require "../src/metadata_exporter.rb"

class MetadataExporterRunner < Runner

	def initialize
		super()
		init_options("../config/settings.yml")
		init_logger()
	end

	def run!
		begin
			MetadataExporter.new(@options, @logger).execute!
		rescue Exception => e
			@logger.fatal e.message
			@logger.fatal e.backtrace.inspect
		ensure
			@logger.close
		end
	end
end

MetadataExporterRunner.new.run!