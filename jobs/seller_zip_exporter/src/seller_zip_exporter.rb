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
		date_s = Date.today.to_s.gsub("-","")

		appraisal_groups = client.query('SELECT Id, Name FROM CollaborationGroup WHERE Name LIKE \'%Appraisals%\'')

		appraisal_groups.each do |group|
			name = group.Name

			if !name.match(/^(\D+)\s-\sAppraisals/).nil? then				
				seller = "#{$1}"
				parentId = group.Id

				zip_folders = client.query("SELECT Id, Title, ContentDescription, ContentFileName, ContentType, ContentData, Type from FeedItem WHERE ParentID = '#{parentId}'")
				zip_folders.each do |zip|
					if zip.ContentType == "application/zip" then
						zip_filename = zip_path+"/#{seller}_#{date_s}_#{zip.Title}.zip"
						puts zip_filename
						
						content = client.get zip.ContentData
						f = File.new(zip_filename, "wb")
						f.write(content.body)
					end
				end				
			end
		end
	end
	
end