require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require "#{ENV['RUNNER_PATH']}/lib/logger.rb"
require 'net/sftp'
require 'csv'
require 'date'
require 'fileutils'

class MLHExtract < Job
        def initialize(options, logger)
                super(options, logger)
                @path = "/home/salesfuser/infaagent/main/rdtmDir/error"

                @job_ids = {
                        "000O9W0Z00000000002N" => {
                                "folder" => "asset",
                                "filename" => "asset_error"
                        },
                        "000O9W0Z00000000002Q" => {
                                "folder" => "reo",
                                "filename" => "reo_error"
                        },
                        "000O9W0Z00000000002O" => {
                                "folder" => "auction",
                                "filename" => "auction_error"
                        },
                        "000O9W0Z00000000002P" => {
                                "folder" => "auction_event",
                                "filename" => "auction_event_error"
                        },
                        "000O9W0Z000000000031" => {
                                "folder" => "offer",
                                "filename" => "winning_bid_error"
                        },
                        "000O9W0Z000000000032" => {
                                "folder" => "offer",
                                "filename" => "losing_bid_error"
                        },
			"000O9W0Z00000000003A" => {
				"folder" => "offer",
				"filename" => "winning_presale_error"
			}
                }
        end

        def execute!
                Net::SFTP.start('fdep.auction.com', 'equator_scripting', :password => 'Mv825y9M') do |sftp|
			Dir.foreach(@path) do |file| 
			       @job_ids.keys.each do |job_id|
					if file.match(/#{job_id}_\d{1}_\d{2}_\d{4}_\d{2}_\d{2}/) && !File.size?("#{@path}/#{file}").nil? then
						timestamp = file.match(/\d{1}_\d{2}_\d{4}_\d{2}_\d{2}/)
						folder = @job_ids[job_id]["folder"]
						filename = @job_ids[job_id]["filename"]
						filename = "#{filename}_#{timestamp}"
                                                
						#push file to SFTP
						sftp.upload!("#{@path}/#{file}","/MLH/error/#{folder}/#{filename}.csv")
						
						#archive error file
						FileUtils.mv("#{@path}/#{file}", "#{@path}/archive/#{file}")
                                        end
				end
			end
		end
	end
end
