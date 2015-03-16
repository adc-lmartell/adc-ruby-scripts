module RunnerInterface

	class InterfaceNotImplemented < NoMethodError
	end

	def self.included(klass)
		klass.send(:include, RunnerInterface::Methods)
		klass.send(:extend, RunnerInterface::Methods)
		klass.send(:extend, RunnerInterface::ClassMethods)
	end

	module Methods

		def api_not_implemented(klass, method_name = nil)
			if method_name.nil?
				caller.first.match(/in \`(.+)\'/)
				method_name = $1
			end
			raise RunnerInterface::InterfaceNotImplemented.new("#{klass.class.name} needs to implement '#{method_name}' for interface #{self.name}!")
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

require 'logger'
require 'yaml'
require 'erb'

class Runner
	include RunnerInterface

	needs_implementation :run!

	def initialize
		raise "Environment variable RUNNER_PATH must be set before using the library." unless ENV.has_key?("RUNNER_PATH")

		config_filename = "#{ENV["RUNNER_PATH"]}/config/global-settings.yml"

		init_options(config_filename)
		init_logger()
	end

	def init_options(filename)
		@options ||= {}

		if File.exists?(filename)
			current_options = YAML.load(ERB.new(File.read(filename)).result)
			@options.merge!(current_options)
		end
	end

	def init_logger()
		@logger = (@options.has_key?("logger") && @options["logger"].has_key?("filename") && @options["logger"].has_key?("frequency") ? Logger.new(@options["logger"]["filename"], @options["logger"]["frequency"]) : nil)
	end
end