require "#{ENV['RUNNER_PATH']}/lib/runner.rb"
require "#{ENV['RUNNER_PATH']}/jobs/auction_seller_update/src/auction_seller_update.rb"

class AuctionSellerUpdateRunner < Runner

	def initialize
		super()
		init_options("../config/settings.yml")
		init_logger()
	end

	def run!
		begin
			AuctionSellerUpdate.new(@options, @logger).execute!
		rescue Exception => e
			@logger.fatal e.message
			@logger.fatal e.backtrace.inspect
		ensure
			@logger.close
		end
	end
end

AuctionSellerUpdateRunner.new.run!