require "#{ENV['RUNNER_PATH']}/lib/runner.rb"
require "#{ENV['RUNNER_PATH']}/jobs/mlh_sfdc_migration/src/mlh_sfdc_migrator.rb"
# require "/Users/kdavis/Documents/Git/adc-ruby-scripts/lib/runner.rb"
# require "/Users/kdavis/Documents/Git/adc-ruby-scripts/jobs/mlh_sfdc_migration/src/mlh_sfdc_migrator.rb"

class MlhSfdcMigrationRunner < Runner

	def initialize
		super()
		init_options("#{ENV['RUNNER_PATH']}/jobs/mlh_sfdc_migration/config/settings.yml")
		init_logger()
	end

	def run!
		begin
			MlhSfdcMigrator.new(@options, @logger).execute!
		rescue Exception => e
			@logger.fatal e.message
			@logger.fatal e.backtrace.inspect
		ensure
			@logger.close
		end
	end
end

MlhSfdcMigrationRunner.new.run!