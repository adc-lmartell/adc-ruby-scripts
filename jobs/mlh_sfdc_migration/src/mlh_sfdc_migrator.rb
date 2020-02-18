require "#{ENV['RUNNER_PATH']}/lib/job.rb"
require 'csv'
require 'restforce'
require 'net/sftp'
require 'Date'
# require "/Users/kdavis/Documents/Git/adc-ruby-scripts/lib/job.rb"

class MlhSfdcMigrator < Job
    attr_accessor :mlh_output, :sfdc_output, :comp_fields

    def initialize(options, logger)
        super(options, logger)

        @local_path = "#{ENV['DOWNLOADS_PATH']}"
        puts @local_path
        @sftp_host = "#{ENV['TRIN_SFTP_HOST']}"
        @sftp_user = "#{ENV['TRIN_SFTP_USER']}"
        @sftp_pwd = "#{ENV['TRIN_SFTP_PWD']}"
        @missing_output = {}
        @mlh_output = {}
        @sfdc_output = {}

        @sfdc_comp_fields = [
            {"mlh" => "sellerCode", "sfdc" => "Seller_Code__c", "type" => "string"},
            {"mlh" => "globalPropId", "sfdc" => "Trinity_Global_Property_Id__c", "type" => "string"},
            {"mlh" => "dropboxResponseNumber", "sfdc" => "Attorney_Webservice_Automation_ID__c", "type" => "string"},
            {"mlh" => "fclSaleDate", "sfdc" => "FCL_Sale_Date__c", "type" => "date"},
            {"mlh" => "fclSaleTime", "sfdc" => "FCL_Sale_Time__c", "type" => "time"},
            {"mlh" => "trusteeSaleNumber", "sfdc" => "Trustee_Sale_Number__c", "type" => "string"},
            {"mlh" => "outsourcerCode", "sfdc" => "Outsourcer_Code__c", "type" => "string"}
        ]

        @mlh_comp_fields = {
            "Id" => "SFID",
            "Property__c" => "SFID_Opportunity"
        }
    end

    def execute!
        get_sfdc_rows()

        if get_mlh_rows() then
            puts "start comp"

            # SFID is Campaign id
            CSV.parse(@mlh_data, headers: true, liberal_parsing: true, converters: [->(v) {
                if !v.nil? then             
                    v = v.gsub(/\n/,"")
                    v = v.gsub(/[^a-zA-Z0-9\s\-]/,"")
                end
            }]) do |mlh_row|
                sfdc_row_index = -1
                mlh_address = get_normal_address(mlh_row["propertyAddress"],mlh_row["propertyCity"],mlh_row["propertyState"],mlh_row["propertyZip"])
                account_no = mlh_row["loanNo"]
                serv_address_match = @sfdc_by_serv_address.has_key?(mlh_address)
                attny_address_match = @sfdc_by_attny_address.has_key?(mlh_address)
                inv_address_match = @sfdc_by_inv_address.has_key?(mlh_address)     

                if @sfdc_by_investor.has_key?(account_no) || @sfdc_by_servicer.has_key?(account_no) then
                    sfdc_row_index = @sfdc_by_servicer[account_no] || @sfdc_by_investor[account_no]
                elsif serv_address_match || attny_address_match || inv_address_match then
                    sfdc_row_index = @sfdc_by_attny_address[mlh_address] || @sfdc_by_serv_address[mlh_address] || @sfdc_by_inv_address[mlh_address]
                end

                if sfdc_row_index >= 0 then
                    sfdc_row = @sfdc_data[sfdc_row_index]

                    update_mlh_address = false
                    
                    if serv_address_match && !attny_address_match && !sfdc_row["Attorney_Property_Address__c"].nil? then 
                        update_mlh_address = true
                    end

                    begin
                        if !serv_address_match && !attny_address_match && !sfdc_row["Attorney_Property_Address__c"].nil? && Date.parse(sfdc_row["FCL_Sale_Date__c"]) > Date.parse(mlh_row['fclSaleDate']) then
                            update_mlh_address = true
                        end

                        if !serv_address_match && !attny_address_match && !sfdc_row["Attorney_Property_Address__c"].nil? && Date.parse(sfdc_row["FCL_Sale_Date__c"]) == Date.parse(mlh_row['fclSaleDate']) && DateTime.parse(sfdc_row["Attorney_Webservice_Automation_ID__c"]) > DateTime.parse(mlh_row['dropboxResponseNumber']) then
                            update_mlh_address = true
                        end
                    rescue
                        if mlh_row["fclSaleDate"].nil? then 
                            update_mlh_address = true
                        end
                    end
                    
                    # 
                    # SFDC UPDATES
                    # 
                    update_sfdc = false
                    if account_no = sfdc_row["Servicer_Account_Number__c"] || account_no = sfdc_row["Investor_Account_Number__c"] then
                        sfdc_output_row = {
                            "Id" => sfdc_row["Id"],
                            "Property_Intake_Id" => sfdc_row["PI_Id"],
                            "Servicer_Account_Number__c" => sfdc_row["Servicer_Account_Number__c"],
                            "Investor_Account_Number__c" => sfdc_row["Investor_Account_Number__c"],
                            "propertyAddress" => mlh_row["propertyAddress"],
                            "propertyCity" => mlh_row["propertyCity"],
                            "propertyState" => mlh_row["propertyState"],
                            "propertyZip" => mlh_row["propertyZip"],                            
                            "Servicer_Property_Address__c" => sfdc_row["Servicer_Property_Address__c"],
                            "Servicer_Property_City__c" => sfdc_row["Servicer_Property_City__c"],
                            "Servicer_Property_State__c" => sfdc_row["Servicer_Property_State__c"],
                            "Servicer_Property_Postal_Code__c" => sfdc_row["Servicer_Property_Postal_Code__c"],
                            "Attorney_Property_Address__c" => sfdc_row["Attorney_Property_Address__c"],
                            "Attorney_Property_City__c" => sfdc_row["Attorney_Property_City__c"],
                            "Attorney_Property_State__c" => sfdc_row["Attorney_Property_State__c"],
                            "Attorney_Property_Postal_Code__c" => sfdc_row["Attorney_Property_Postal_Code__c"],
                            "Investor_Property_Address__c" => sfdc_row["Investor_Property_Address__c"],
                            "Investor_Property_City__c" => sfdc_row["Investor_Property_City__c"],
                            "Investor_Property_State__c" => sfdc_row["Investor_Property_State__c"],
                            "Investor_Property_Postal_Code__c" => sfdc_row["Investor_Property_Postal_Code__c"]
                        }

                        @sfdc_comp_fields.each do |field|
                            mlh_val = mlh_row[field["mlh"]]
                            sfdc_val = sfdc_row[field["sfdc"]]
                            
                            if field["type"] == "date" then
                                begin
                                    mlh_val = !mlh_val.nil? ? Date.parse(mlh_val) : ''
                                rescue
                                    mlh_val = ''
                                end

                                begin
                                    sfdc_val = !sfdc_val.nil? ? Date.parse(sfdc_val) : ''
                                rescue
                                    sfdc_val = ''
                                end
                            end

                            if mlh_val != sfdc_val then
                                update_sfdc = true
                                sfdc_output_row["Original_#{field["sfdc"]}"] = sfdc_val
                                sfdc_output_row[field["sfdc"]] = mlh_val
                            end

                            # Address updates
                            if !update_mlh_address then
                                if mlh_row["propertyAddress"] != sfdc_row["Property_Address__c"] || mlh_row["propertyCity"] != sfdc_row["Property_City__c"] || mlh_row["propertyState"] != sfdc_row["Property_State__c"] || mlh_row["propertyZip"] != sfdc_row["Property_Postal_Code__c"] then

                                    update_sfdc = true
                                    sfdc_output_row["Original_Property_Address__c"] = sfdc_row["Property_Address__c"]
                                    sfdc_output_row["Property_Address__c"] = mlh_row["propertyAddress"]
                                    sfdc_output_row["Original_Property_City__c"] = sfdc_row["Property_City__c"]
                                    sfdc_output_row["Property_City__c"] = mlh_row["propertyCity"]
                                    sfdc_output_row["Original_Property_State__c"] = sfdc_row["Property_State__c"]
                                    sfdc_output_row["Property_State__c"] = mlh_row["propertyState"]
                                    sfdc_output_row["Original_Property_Postal_Code__c"] = sfdc_row["Property_Postal_Code__c"]
                                    sfdc_output_row["Property_Postal_Code__c"] = mlh_row["propertyZip"]
                                end
                            end                            
                        end

                        if update_sfdc then
                            @sfdc_output[sfdc_row["Id"]] = sfdc_output_row
                        end
                    end

                    # 
                    # MLH UPDATES
                    # 
                    update_mlh = false
                    mlh_output_row = {
                        "propertyId" => mlh_row["propertyId"], 
                        "globalPropId" => mlh_row["globalPropId"], 
                        "sellerCode" => mlh_row["sellerCode"],
                        "loanNo" => mlh_row["loanNo"],
                        "auctionId" => mlh_row["auctionId"],
                        "venueId" => mlh_row["venueId"],
                        "auctionNumber" => mlh_row["eventId"],
                        "auctionDate" => mlh_row["fclSaleDate"],
                        "propertyAddress" => mlh_row["propertyAddress"],
                        "propertyCity" => mlh_row["propertyCity"],
                        "propertyState" => mlh_row["propertyState"],
                        "propertyZip" => mlh_row["propertyZip"],
                        "auction_date" => mlh_row["fclSaleDate"],
                        "SFDC_FCL_SALE_DATE" => sfdc_row["FCL_Sale_Date__c"],
                        "dropbox_response_id" => mlh_row["dropboxResponseNumber"],
                        "SFDC_Webservice_ID" => sfdc_row["Attorney_Webservice_Automation_ID__c"]
                    }

                    @mlh_comp_fields.each do |sfdc_field, mlh_field|
                        sfdc_val = sfdc_row[sfdc_field]
                        mlh_val = mlh_row[mlh_field]

                        # always map MLH values
                        mlh_output_row[mlh_field] = sfdc_val
                        
                        if sfdc_val != mlh_val then
                            update_mlh = true
                            mlh_output_row["original_#{mlh_field}"] = mlh_field                            
                        end                        

                        if update_mlh_address then
                            mlh_output_row["original_propertyAddress"] = mlh_row["propertyAddress"]
                            mlh_output_row["propertyAddress"] = sfdc_row["Attorney_Property_Address__c"]  
                            mlh_output_row["original_propertyCity"] = mlh_row["propertyCity"]                          
                            mlh_output_row["propertyCity"] = sfdc_row["Attorney_Property_City__c"]
                            mlh_output_row["original_propertyState"] = mlh_row["propertyState"]    
                            mlh_output_row["propertyState"] = sfdc_row["Attorney_Property_State__c"]
                            mlh_output_row["original_propertyZip"] = mlh_row["propertyZip"]    
                            mlh_output_row["propertyZip"] = sfdc_row["Attorney_Property_Postal_Code__c"]
                        end                        
                    end
                    
                    if update_mlh then
                        @mlh_output[mlh_row["propertyId"]] = mlh_output_row
                    end
                else
                    @missing_output[mlh_row["propertyId"]] = mlh_row
                end
            end

            puts "sfdc to mlh comp complete mlh: #{@mlh_output.keys.length} | sfdc: #{@sfdc_output.keys.length} | failed: #{@missing_output.keys.length}"
            puts "begin MLH write"

            CSV.open("#{@local_path}/mlh_output.csv", "wb") do |csv|
                headers = ["propertyId","globalPropId","sellerCode","loanNo","auctionId","venueId","auctionNumber","auctionDate","original_propertyAddress","propertyAddress","original_propertyCity","propertyCity","original_propertyState","propertyState","original_propertyZip","propertyZip","auction_date","SFDC_FCL_SALE_DATE","dropbox_response_id","SFDC_Webservice_ID"]

                @mlh_comp_fields.each do |key, val|
                    headers << val
                end

                csv << headers

                @mlh_output.each do |key, obj|
                    row = []

                    headers.each do |h|
                        row << obj[h]
                    end

                    csv << row
                end
                
            end

            @sftp.upload!("#{@local_path}/mlh_output.csv","/mlh_migration/output/mlh_output.csv")
            File.delete("#{@local_path}/mlh_output.csv")

            puts "begin SFDC write"

            CSV.open("#{@local_path}/sfdc_output.csv", "wb") do |csv|
                headers = ["Id","Property_Intake_Id","Servicer_Account_Number__c","Investor_Account_Number__c","propertyAddress","propertyCity","propertyState","propertyZip","Original_Property_Address__c","Property_Address__c","Original_Property_City__c","Property_City__c","Original_Property_State__c","Property_State__c","Original_Property_Postal_Code__c","Property_Postal_Code__c","Servicer_Property_Address__c","Servicer_Property_City__c","Servicer_Property_State__c","Servicer_Property_Postal_Code__c","Attorney_Property_Address__c","Attorney_Property_City__c","Attorney_Property_State__c","Attorney_Property_Postal_Code__c","Investor_Property_Address__c","Investor_Property_City__c","Investor_Property_State__c","Investor_Property_Postal_Code__c"]

                @sfdc_comp_fields.each do |field|
                    headers << "Original_#{field["sfdc"]}"
                    headers << field["sfdc"]
                end

                csv << headers

                @sfdc_output.each do |key, obj|
                    row = []

                    headers.each do |h|
                        row << obj[h]
                    end

                    csv << row
                end
                
            end

            @sftp.upload!("#{@local_path}/sfdc_output.csv","/mlh_migration/output/sfdc_output.csv")
            File.delete("#{@local_path}/sfdc_output.csv")

            puts "begin no match write"

            CSV.open("#{@local_path}/failed_matches.csv", "wb") do |csv|
                headers = ["propertyId","globalPropId","sellerCode","loanNo","auctionId","venueId","eventId","fclSaleDate","fclSaleTime","propertyAddress","propertyCity","propertyState","propertyZip","SFID","SFID_Opportunity"]

                csv << headers

                @missing_output.each do |key, obj|
                    row = []

                    headers.each do |h|
                        row << obj[h]
                    end

                    csv << row
                end
                
            end

            @sftp.upload!("#{@local_path}/failed_matches.csv","/mlh_migration/output/failed_matches.csv")
            File.delete("#{@local_path}/failed_matches.csv")

            File.delete("#{@local_path}/sfdc_campaigns.csv")
        end
    end

    def get_mlh_rows
        # pull mlh file locally
        if @sftp.nil? then
            @sftp = Net::SFTP.start(@sftp_host, @sftp_user, :password => @sftp_pwd)   
        end

        @mlh_data = @sftp.download!("/mlh_migration/mlh_extract.csv")

        puts "download successful"

        return true
    end

    def get_sfdc_rows
        puts @sftp_host
        if(@sftp.nil?) then
            @sftp = Net::SFTP.start(@sftp_host, @sftp_user, :password => @sftp_pwd)       
        end

        @sftp.download!("/mlh_migration/sfdc_campaigns.csv", "#{@local_path}/sfdc_campaigns.csv")
        @sfdc_data =  CSV.read("#{@local_path}/sfdc_campaigns.csv", headers: true)
        @sfdc_by_investor = {}
        @sfdc_by_servicer = {}
        @sfdc_by_serv_address = {}
        @sfdc_by_attny_address = {}
        @sfdc_by_inv_address = {}
        
        row_num = 0
        puts "sfdc row count #{@sfdc_data.length}"
        while row_num <= @sfdc_data.length
            row = @sfdc_data[row_num] 
            
            if !row.nil?
                serv_addr = get_normal_address(row["Servicer_Property_Address__c"],row["Servicer_Property_City__c"],row["Servicer_Property_State__c"],row["Servicer_Property_Postal_Code__c"])
                attny_addr = get_normal_address(row["Attorney_Property_Address__c"],row["Attorney_Property_City__c"],row["Attorney_Property_State__c"],row["Attorney_Property_Postal_Code__c"])
                inv_addr = get_normal_address(row["Investor_Property_Address__c"],row["Investor_Property_City__c"],row["Investor_Property_State__c"],row["Investor_Property_Postal_Code__c"])

                if serv_addr != "INVALID" then
                    @sfdc_by_serv_address[serv_addr] = row_num
                end

                if attny_addr != "INVALID" then
                    @sfdc_by_attny_address[attny_addr] = row_num
                end

                if inv_addr != "INVALID" then
                    @sfdc_by_inv_address[inv_addr] = row_num
                end

                if !row["Investor_Account_Number__c"].nil? then
                    loan = trim_loan(row["Investor_Account_Number__c"])
                    @sfdc_by_investor[loan] = row_num
                end

                if !row["Servicer_Account_Number__c"].nil? then
                    loan = trim_loan(row["Servicer_Account_Number__c"])
                    @sfdc_by_servicer[loan] = row_num
                end
            end

            row_num = row_num+1
        end
    end

    def get_normal_address(street, city, state, zip)
        if street.nil? || city.nil? || state.nil? || zip.nil?
            return "INVALID"
        end

        return "#{street}#{city}#{state}#{zip}".gsub(/[^A-Za-z0-9]/,"").downcase
    end

    def trim_loan(loan)
        return loan.sub(/^0*/,"")
    end
end