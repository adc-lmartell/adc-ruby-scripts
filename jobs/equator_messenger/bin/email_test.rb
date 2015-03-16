require 'ntlm/smtp'

from_addr = 'lmartell@auction.com'
to_addr = 'robertb@auction.com'

mail_body = <<-EOS
From: #{from_addr}
To: #{to_addr}
Subject: Ruby Automated E-mail
Content-Type: text/plain

You have time to chat about OOA and outstanding items?
EOS

smtp = Net::SMTP.new('exchange.landstaff.com')
smtp.start('nrpi.local', 'nrpi\\lmartell', 'Auction1', :ntlm) do |smtp|
  smtp.send_mail(mail_body, from_addr, to_addr)
end