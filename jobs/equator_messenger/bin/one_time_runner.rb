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

CSV.foreach('messages2.csv') do |row|
	unless index == 0
		messages.push({ :reo_number => row[0], :subject => row[1], :body => row[2] })
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

				b.links(:href, '#ui-tabs-6').last.wait_until_present
				b.links(:href, '#ui-tabs-6').last.click

				b.select_list(:id, 'flag_note_alerts').wait_until_present
				b.select_list(:id, 'flag_note_alerts').select(Regexp.new("^AGENT"))
				Watir::Wait.until { b.select_list(:id, 'flag_note_alerts').include?(Regexp.new("^AGENT")) }

				b.select_list(:id, 'flag_note_alerts').select(Regexp.new("^ASSET MANAGER"))
				Watir::Wait.until { b.select_list(:id, 'flag_note_alerts').include?(Regexp.new("^ASSET MANAGER")) }

				b.select_list(:id, 'flag_note_alerts').select(Regexp.new("^SR ASSET MANAGER"))

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