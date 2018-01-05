require "#{ENV['RUNNER_PATH']}/lib/runner.rb"
require "../src/sftp_file_copy.rb"

class SftpFileCopyRunner < Runner

	def initialize
		super()
		init_options("../config/settings.yml")
		init_logger()
	end

	def run!
		begin
			SftpFileCopy.new(@options, @logger).execute!
		rescue Exception => e
			puts e
			@logger.fatal e.message
			@logger.fatal e.backtrace.inspect
		ensure
			@logger.close
		end
	end
end

SftpFileCopyRunner.new.run!