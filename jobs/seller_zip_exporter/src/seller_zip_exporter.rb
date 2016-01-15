 require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require "#{ENV['RUNNER_PATH']}/lib/logger.rb"
require 'net/sftp'
require 'date'
require 'base64'
require 'zip'
require 'stringio'

class SellerZipExporter < Job

	class InvalidFileError < RuntimeError
	end

	class EmptyDirectory < RuntimeError
	end

	def initialize(options, logger)
		super(options, logger)		
	end

	def execute!
		restforce_client = get_restforce_client(@options['salesforce']['external']['production'], true)
		client = restforce_client[:client]
		@logger.info "Login successful"	

		zip_path = "#{ENV['ZIP_PATH']}"

		appraisal_groups = client.query('SELECT Id, Name FROM CollaborationGroup WHERE Name LIKE \'%Appraisals%\'')

		appraisal_groups.each do |group|
			name = group.Name

			unless name.match(/^(\D+)\s-\sAppraisals/).nil? then
				seller = "#{$1}".gsub(/[^\D]/, "")
				parentId = group.Id

				zip_folders = client.query("SELECT Id, Title, ContentType, ContentData, CreatedDate from FeedItem WHERE ParentID = '#{parentId}'")
				zip_folders.each do |zip|
					if zip.ContentType == "application/zip" then
						created_date = zip.CreatedDate.split(".")[0].gsub(/[\-\:]/, "")

						zip_filename = "#{zip_path}/#{seller}_#{created_date}_#{zip.Title}.zip"
						
						content = client.get zip.ContentData
						f = File.new(zip_filename, "wb")
						f.write(content.body)

						@logger.info "FeedItem ID: #{zip.Id}"
					end
				end				
			end
		end
	end
	
end