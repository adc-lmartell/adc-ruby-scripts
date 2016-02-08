require "#{ENV['RUNNER_PATH']}/lib/runner.rb"
require "../src/mls_file_rename.rb"

class MlsFileRenameRunner < Runner

	def initialize
		super()
		init_options("../config/settings.yml")
		init_logger()
	end

	def run!
		begin
			MlsFileRename.new(@options, @logger).execute!
		rescue Exception => e
			puts e
			@logger.fatal e.message
			@logger.fatal e.backtrace.inspect
		ensure
			@logger.close
		end
	end
end

MlsFileRenameRunner.new.run!