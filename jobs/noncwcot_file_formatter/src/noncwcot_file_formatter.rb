require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require "#{ENV['RUNNER_PATH']}/lib/logger.rb"
require 'net/sftp'
require 'csv'

class NonCWCOTFileFormatter < Job

	# Exception class for the files that are required for the script to run
	class SystemFileDependencyException < Exception
		def initialize(system_file)
			@system_file = system_file
		end

		def to_s
			"There is no system file present in the SFTP folder with the following name: #{@system_file}"
		end
	end

	# Exception class for the required columns needed in the seller matrix
	class MissingMatrixColumnException < Exception
		def initialize(required_field, source_file)
			@required_field = required_field
			@source_file = source_file
		end

		def to_s
			"Missing required column #{@required_field} in #{@source_file}"
		end
	end

	def initialize(options, logger)
		super(options, logger)		
	end

	# Connect to SFTP to pull the seller datatapes and prepare the asset load file
	def execute!
		Net::SFTP.start(@options['sftp']['seller_datatapes']['host'], @options['sftp']['seller_datatapes']['username'], :password => @options['sftp']['seller_datatapes']['password']) do |sftp|
			entries = sftp.dir.glob("/seller_datatapes", "*.csv").map { |e| e.name }

			# Ensure we have the right files before we proceed
			validate_system_files(entries)

			# Download the seller files and prepare the load file
			download_and_prepare(sftp)

			# Cleanup all the temporary files
			cleanup_temp_files(sftp)
		end
	end
	
	private

	# Iterate over all system files and make sure they are in the SFTP folder
	def validate_system_files(entries)
		[@options['system_files']['seller_datatape'], @options['system_files']['seller_matrix'], @options['system_files']['asset_load']].each do |f|
			raise SystemFileDependencyException.new(f) unless entries.include?(f)
		end
	end

	# Remove the local files downloaded from SFTP and archive the seller datatape
	def cleanup_temp_files(sftp)
		[@options['system_files']['seller_datatape'], @options['system_files']['seller_matrix'], @options['system_files']['asset_load']].each do |f|
			if File.exists?(f) then
				File.delete(f)
			end
		end
		sftp.rename("/seller_datatapes/#{@options['system_files']['seller_datatape']}", "/seller_datatapes/archive/#{@options['system_files']['seller_datatape']}-#{Time.now.strftime('%Y%m%d%H%M%S')}")
	end

	# Download the seller files (matrix and datatape) and then convert the datatape into the asset load file
	def download_and_prepare(sftp)
		matrix = Hash.new

		# Download the seller files
		[@options['system_files']['seller_datatape'], @options['system_files']['seller_matrix']].each do |f|
			sftp.download!("/seller_datatapes/#{f}", "#{f}")
		end

		# Validate the required matrix fields are in the spreadsheet
		matrix_rows = CSV.read(@options['system_files']['seller_matrix'])
		header_indices = Hash.new

		# Raise an exception if the required fields are not present in seller matrix
		@options['required_fields']['matrix'].each do |rf|
			raise MissingMatrixColumnException.new(rf, @options['system_files']['seller_matrix']) unless matrix_rows[0].include?(rf)
			header_indices[rf] = matrix_rows[0].index(rf)
		end

		# Build the matrix configuration map that will be used later in the conversion of the datatape
		matrix_rows.each_with_index do |row, i|
			matrix[row[header_indices['Seller Code']]] = get_matrix_details(row, header_indices) unless i == 0
		end
		
		# Pull the seller datatape into the config hash 
		datatape_rows = CSV.read(@options['system_files']['seller_datatape'])

		# Build the asset load file from the seller datatape and the matrix configuration map
		CSV.open(@options['system_files']['asset_load'], "wb") do |csv|
			csv << datatape_rows[0].push(header_indices.keys).flatten!

			datatape_rows.each_with_index do |row, i|
				csv << add_row(row, header_indices, matrix) unless i == 0 
			end
		end

		# Upload the CSV file to the SFTP folder
		sftp.upload!(@options['system_files']['asset_load'], "/seller_datatapes/#{@options['system_files']['asset_load']}")
	end

	# Add a row to the asset load file by appending on the matrix configuration
	def add_row(row, header_indices, matrix)
		seller_code = row[2]

		header_indices.keys.each do |k|
			row.push((matrix.has_key?(seller_code) ? matrix[seller_code][k] : nil))
		end
		row
	end

	# Pull in the matrix configuration based on the seller code 
	def get_matrix_details(row, header_indices)
		seller_code_map = Hash.new

		header_indices.each_pair do |k, v|
			seller_code_map[k] = row[v]
		end

		seller_code_map
	end

end