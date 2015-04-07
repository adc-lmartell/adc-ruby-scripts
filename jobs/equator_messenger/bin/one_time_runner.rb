require 'watir-webdriver'
require 'watir-webdriver/wait'
require 'csv'

login_credentials = {
	:url => 'https://vendors.equator.com',
	:username => 'bac_auction@auction.com',
	:password => 'Auction2014'
}
messages = []
index = 0

CSV.foreach('EventStartReminder-20150406.csv') do |row|
	unless index == 0
		messages.push({ 
			:contact_agent => !row[0].nil?,
			:contact_sr_am => !row[1].nil?,
			:contact_am => !row[2].nil?,
			:reo_number => row[3], 
			:subject => row[4], 
			:body => row[5]
		})
	end
	index += 1
end

unless messages.empty?
	b = Watir::Browser.new

	b.goto login_credentials[:url]
	b.text_field(:name, 'enter_username').set login_credentials[:username]
	b.text_field(:name, 'enter_password').set login_credentials[:password]
	b.button(:name, 'btnLogin').click

	CSV.open('messages.out.csv', 'wb') do |csv|
		csv << ['REO Number', 'Status', 'Message']

		messages.each do |message|
			begin
				b.goto "https://vendors.equator.com/index.cfm?event=property.search&clearCookie=true"
				b.select_list(:name, 'property_SearchType').select "REO Number"
				b.text_field(:name, 'property_SearchText').set message[:reo_number]
				b.button(:name, 'btnSearch').click

				b.links(:href, /property\.viewEvents/).last.click

				b.links(:href, '#ui-tabs-2').last.wait_until_present
				b.links(:href, '#ui-tabs-2').last.click

				b.links(:text, 'Add Messages').last.wait_until_present
				b.links(:text, 'Add Messages').last.click

				b.select_list(:id, 'flag_note_alerts').wait_until_present

				if message[:contact_agent] then
					b.select_list(:id, 'flag_note_alerts').select(Regexp.new("^AGENT"))
					Watir::Wait.until { b.select_list(:id, 'flag_note_alerts').include?(Regexp.new("^AGENT")) }
				end

				if message[:contact_am] then
					b.select_list(:id, 'flag_note_alerts').select(Regexp.new("^ASSET MANAGER"))
					Watir::Wait.until { b.select_list(:id, 'flag_note_alerts').include?(Regexp.new("^ASSET MANAGER")) }
				end

				if message[:contact_sr_am] then
					b.select_list(:id, 'flag_note_alerts').select(Regexp.new("^SR ASSET MANAGER"))
					Watir::Wait.until { b.select_list(:id, 'flag_note_alerts').include?(Regexp.new("^SR ASSET MANAGER")) }
				end

				b.text_field(:name, 'title').set message[:subject]
				b.textarea(:name, 'note').set message[:body]

				b.button(:name => 'noteSubmit').click
				b.button(:name => 'noteSubmit').wait_while_present

				csv << [message[:reo_number], 'Success', '']
			rescue Exception => e
				csv << [message[:reo_number], 'Error', e.message]
			end
		end
	end
end