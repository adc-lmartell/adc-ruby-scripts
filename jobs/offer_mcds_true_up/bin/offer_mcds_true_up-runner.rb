require "#{ENV['RUNNER_PATH']}/lib/runner.rb"
require "../src/offer_mcds_true_up.rb"

class OfferMcdsTrueUpRunner < Runner

	def initialize
		super()
		init_options("../config/settings.yml")
		init_logger()
	end

	def run!
		begin
			OfferMcdsTrueUp.new(@options, @logger).execute!
		rescue Exception => e
			@logger.fatal e.message
			@logger.fatal e.backtrace.inspect
		ensure
			@logger.close
		end
	end
end

OfferMcdsTrueUpRunner.new.run!