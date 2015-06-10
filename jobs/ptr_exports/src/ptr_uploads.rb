require 'net/sftp'
require 'base64'
require 'date'

class PTRUploads < Job
	def initialize(options, logger)
		super(options, logger)
	end

	def execute!
		
		restforce_client = get_restforce_client(@options['salesforce']['external']['production'], true)
		client = restforce_client[:client]

		@logger.info "Login successful"		

		Net::SFTP.start('fdep.auction.com', 'wells-fargo', :password => 'Y8pWRk5m') do |sftp|	
			sftp.dir.foreach("/PTR") do |file|
				if file.name =~ /^*\.pdf$/ then
			    	filename = File.basename(file.name)
			    	
			    	sf_id = filename[/^(.*?)-/,1]
					content_title = filename[/\-(.*?)$/,1]
					puts sf_id.inspect
					begin
						data = sftp.download!("PTR/"+filename)
						feeditem = client.create 'FeedItem', ParentId: sf_id, ContentData: Base64::encode64(data), ContentFileName: content_title, Body: 'This is a PTR document', Visibility: 'AllUsers'
						client.update('Auction__c', Id: sf_id, PTR_Upload_Date__c: Date.today)
						sftp.rename!("PTR/"+filename, "complete/"+filename)							
					rescue
						sftp.rename!("PTR/"+filename, "failed/"+filename)
					end
		    	end	    	
		  	end
		end
	end
end