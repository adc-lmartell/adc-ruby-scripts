require 'json'
require 'date'

class IntakeFieldException < RuntimeError
end

class SfdcDmlError < RuntimeError
end

class BatchLog

	@@logs = {}

	def initialize(batchId)
		puts batchId.inspect

		if !@@logs.has_key?(batchId) then
			@@logs[batchId] = {"info" => [], "exception" => []}
		end
	end

	def self.get_log_json(batchId)
		config = {}	

		info = ''
		if @@logs.has_key?(batchId) then
			
			@@logs[batchId]["info"].each do |log|
				info += "[#{log.type}] #{log.msg}"
			end

			@@logs[batchId]["exception"].each do |log|
				info += "[#{log.type}] #{log.msg}"
			end
							
		end

		config["Batch_Load_Job__c"] = batchId
		config["Process_Log__c"] = info
		config["Run_Date__c"] = Date.today

		JSON.generate(config)
	end

	def self.get_batch_ids
		@@logs.keys
	end

	def self.log_info(batchId, msg)
		@@logs[batchId]["info"] << LogMessage.new(batchId, "INFO", msg)
	end

	def self.log_exception(batchId, errors)
		@@logs[batchId]["exception"] << LogMessage.new(batchId, "EXCEPTION", errors.message)

		puts @@logs.inspect
	end


	class LogMessage
		attr_accessor :batchId, :type, :msg

		def initialize(batchId, type, msg)
			@batchId = batchId
			@msg = msg
			@type = type
		end
	end
end