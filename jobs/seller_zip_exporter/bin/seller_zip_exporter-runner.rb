require "#{ENV['RUNNER_PATH']}/lib/runner.rb"
require "../src/seller_zip_exporter.rb"

class SellerZipRunner < Runner

	def initialize
		super()
		init_options("../config/settings.yml")
		init_logger()
	end

	def run!
		begin
			SellerZipExporter.new(@options, @logger).execute!
		rescue Exception => e
			puts e
			@logger.fatal e.message
			@logger.fatal e.backtrace.inspect
		ensure
			@logger.close
		end
	end
end

SellerZipRunner.new.run!