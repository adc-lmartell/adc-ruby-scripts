module JobInterface

	class InterfaceNotImplemented < NoMethodError
	end

	def self.included(klass)
		klass.send(:include, JobInterface::Methods)
		klass.send(:extend, JobInterface::Methods)
		klass.send(:extend, JobInterface::ClassMethods)
	end

	module Methods

		def api_not_implemented(klass, method_name = nil)
			if method_name.nil?
				caller.first.match(/in \`(.+)\'/)
				method_name = $1
			end
			raise JobInterface::InterfaceNotImplemented.new("#{klass.class.name} needs to implement '#{method_name}' for interface #{self.name}!")
		end		

	end

	module ClassMethods

		def needs_implementation(name, *args)
			self.class_eval do
				define_method(name) do |*args|
					Runner.api_not_implemented(self, name)
				end
			end
		end

	end

end

require 'restforce'

class Job
	include JobInterface

	needs_implementation :execute!

	def initialize(options, logger)
		@options = options
		@logger = logger
	end
	
	def get_restforce_client(credentials, should_authenticate)
		restforce_client = {}

		restforce_client[:client] = Restforce.new :username => credentials['username'], :password => credentials['password'], :security_token => credentials['security_token'], :host => credentials['host'], :client_id => credentials['client_id'], :client_secret => credentials['client_secret']
		restforce_client[:response] = restforce_client[:client].authenticate! if should_authenticate

		restforce_client
	end

end