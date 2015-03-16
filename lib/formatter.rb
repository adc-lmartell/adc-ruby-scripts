class SfdcFormat
	
	class SfdcRegexEnforcer

		def self.valid_field?(val, type)
			is_valid = true

			if !val.nil? then
				if type.eql?("Date") then
					is_valid = (!val.match(/(\d+)\/(\d+)\/(\d+)/).nil? || !val.match(/(\d+)-(\d+)-(\d+)/).nil?)
				end

				if type.eql?("Phone") then
					is_valid = (val.length == 10 || val.length == 11)	
				end

				if type.eql?("Currency") then
					is_valid = !val.match(/^\d+(\.*)\d+/).nil? 
				end

				if type.eql?("Email") then
					is_valid = !val.match(/(\w+)@(\w+)\.com$/).nil?
				end

				if type.eql?("Number") then
					is_valid = !val.match(/\w+/).nil?
				end
			end

			is_valid
		end

		def self.format_field(val, type)
			
			if !val.nil? then
				if type.eql?("Date") then
					if !val.match(/(\d+)\/(\d+)\/(\d+)/).nil? then
						year = "#{$3}".length == 2 ? "20#{$3}" : "#{$3}"
						month = "#{$2}".length == 1 ? "0#{$2}" : "#{$2}"
						day = "#{$1}".length == 1 ? "0#{$1}" : "#{$1}"
						val = year+"-"+month+"-"+day
					end
				end

				if type.eql?("Phone") then
					val = val.gsub(/-|\(|\)/,"")
				end

				if type.eql?("Currency") then
					val = val.gsub("$","")
				end
			end

			val		
		end		
	end
end