class Bill < ActiveRecord::Base
  
 # before_create :generate_invoice_number
  before_save :generate_grand_total
  before_save :generate_tax_type
  
  belongs_to :other_charges_information
  
  has_many :line_items 
  has_many :products, through: :line_items
  
  belongs_to :customer
  belongs_to :authuser
  
  belongs_to :tax
  
  validates :invoice_number, :bill_date, :tax_id, presence: true
  validates :invoice_number, :uniqueness => {:scope => :authuser_id}
  validate :past_date
#  validates :line_items, presence: true
 # validates :line_items , uniqueness: {:scope => :product_id, :message => "Selected Product is already added to the bill"}
  #validates :line_items, uniqueness: {:message => "Selected Item is already added in the bill"}, :if => Authuser.current
  
  accepts_nested_attributes_for :line_items, :allow_destroy => true
  
#  def generate_invoice_number
 #   if Bill.last.invoice_number.nil?
  #    self.invoice_number = 1000
   # else 
    #  self.invoice_number = Bill.last.invoice_number + 1
   # end
  #end
 
  #def self.last_invoice_number_used
   # return last.invoice_number unless last.nil?
    # return 1000
#end

 # def self.next_invoice_number_to_use
  #  last_invoice_number_used+1
#end
  
  
 
  
  def past_date
    if self.bill_date < Date.today
      errors.add(:bill_date, 'Entered Bill Date is in the past')
     end
   end
  
  def generate_grand_total
    tax_amount = self.tax.tax_rate * 0.01
    total_amount = self.total_bill_price.to_f + self.other_charges.to_f
    total_tax = tax_amount * total_amount
    self.grand_total = total_amount.to_f + total_tax.to_f
  end

  def generate_tax_type
    self.tax_type  = self.tax.tax_type
  end

  def self.to_csv
    CSV.generate do |csv|
      csv << ["Invoice Number", "Bill Date", "Customer", "Tin Number",  "Total Price"]
      all.each do |bill|
       # bill.line_items.each do|a|
       # product = a.product.product_name
       #end
       #product = (a.product.product_name)
         csv << [
           bill.invoice_number, 
           bill.bill_date.strftime("%b %d %Y"), 
           bill.customer.name,
           bill.customer.tin_number, 
           bill.total_bill_price
         ]
      end
    end
  end
  
  
  def get_esugan_number
    @bill = self 
    @tax_type = @bill.tax.tax_type
    @invoice_number = @bill.invoice_number
    @invoice_date = @bill.bill_date
    @customer_tin_number = @bill.customer.tin_number
    @customer_name_address = @bill.customer.name + @bill.customer.city
    @customer_name = @bill.customer.name
   # @bill_product =  @bill.line_items.first.product.product_name
    @product_name =  @bill.line_items.first.product.product_name
    @commodity_name =  @bill.products.first.usercategory.main_category.commodity_name
    @quantity_units = " "+ @bill.line_items.first.quantity.to_s + " " +@bill.line_items.first.product.units
    @other_value = 0
   
    @total_amount = @bill.total_bill_price
    if @bill.other_charges_information_id != nil && @bill.other_charges != nil
      @total_amount += @bill.other_charges
    end
    
    tax_amount = @bill.tax.tax_rate * 0.01
    @total_tax = tax_amount * @total_amount
    @total_tax = @total_tax.round(2)
    @grand_total = @total_amount + @total_tax
    @grand_total = @grand_total.round(2)
    
    begin
      browser = Watir::Browser.new :phantomjs
     # browser.goto  "http://vat.kar.nic.in/"
     # browser.goto "http://164.100.80.121/vat2/"
      browser.goto "http://sugam.kar.nic.in"
      url = nil
      browser.windows.last.use do
        url = browser.url
      end

      browser.goto url
      browser.button(:value,"Continue").click rescue nil
      browser.button(:value,"Conitnue").click rescue nil
      browser.text_field(:id, "UserName").set(@bill.authuser.users.first.esugam_username)
      browser.text_field(:id, "Password").set(@bill.authuser.users.first.esugam_password)
      browser.button(:value,"Login").click
      browser.goto "http://164.100.80.121/vat2/web_vat505/Vat505_Etrans.aspx?mode=new"
     # browser.goto "http://164.100.80.121/vat2/web_vat505/Vat505_Etrans.aspx?mode=new"
      #browser.button(:value,"Continue").click rescue nil
      #browser.goto "#{url}/CheckInvoiceEnabled.aspx?Form=ESUGAM1"
      if @tax_type == "CST"
        browser.radio(:id, "ctl00_MasterContent_rdoStatCat_1").set
        sleep 5
        browser.text_field(:id, "ctl00_MasterContent_txtTIN").set(@customer_tin_number)
         begin
          browser.text_field(:id, "ctl00_MasterContent_txtFromAddrs").set("BANGALORE")
        rescue => e
          sleep 3
        end
        sleep 5
        begin
          browser.text_field(:id, "ctl00_MasterContent_txtNameAddrs").set(@customer_name)
        rescue => e
          sleep 3
        end
        end
    
        
      if @tax_type == "VAT"
      browser.text_field(:id, "ctl00_MasterContent_txtTIN").set(@customer_tin_number)
      browser.send_keys :tab
     end
       
        

      sleep 10
      browser.text_field(:id, "ctl00_MasterContent_txtFromAddrs").set(@bill.authuser.address.city)
      browser.text_field(:id, "ctl00_MasterContent_txtToAddrs").set(@bill.customer.city)
      browser.text_field(:id, "ctl00_MasterContent_txt_commodityname").set(@product_name)
      browser.select_list(:id, "ctl00_MasterContent_ddl_commoditycode").select(@commodity_name)
      browser.text_field(:id, "ctl00_MasterContent_txtQuantity").set(@quantity_units)
      browser.send_keys :tab
      browser.text_field(:id, "ctl00_MasterContent_txtNetValue").set(@total_amount)
      browser.send_keys :enter
      browser.send_keys :tab
      browser.text_field(:id, "ctl00_MasterContent_txtVatTaxValue").set(@total_tax)
      browser.text_field(:id, "ctl00_MasterContent_txtOthVal").set(@other_value)
      sleep 3
      browser.text_field(:id, "ctl00_MasterContent_txtInvoiceNO").set(@bill.invoice_number.to_s)

      browser.button(:value,"SAVE AND SUBMIT").click
      page_html = Nokogiri::HTML.parse(browser.html)
      browser.button(:value,"Exit").click
      browser.link(:id, "link_signout").click
      browser.close
                 
      textual = page_html.search('//text()').map(&:text).delete_if{|x| x !~ /\w/}
      esugam = textual.fetch(7)
      
      if esugam !="e-SUGAM New Entry Form"
        #flash.now[:success] = esugam
        #here assigning the esugam number, as it's asociated with the bill.
        self.update_attributes(esugam: esugam)
      else
        esugam = nil
        logger.error "esugam not scraped properly ,mostly"
       
      end
      
      return esugam
        rescue => e
        browser.close if browser
        logger.error " esugam not being generated " + e.to_s
        logger.info "My Required esugan number is #{e.to_s}"
        self.update_attributes(esugam: e.to_s) if (e.to_s.size  < 15)
        # I am dumping all response here.
      Sugan.create(number: e.to_s)
        
        esugam = nil
        #flash.now[:error] = "There has been an error in generating the esugam,try again later , 
        #if the error does not go away check the esugam username and password , 
        #if everything is ok and a number is still not generated , contact the webmaster" +e.to_s
      end
    end


end
