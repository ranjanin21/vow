class HomePageController < ApplicationController 
  layout_by_action [:index] => "home"
  
  
  def index
    @enquiry_form =  EnquiryForm.new
  end
  
  def read_pdf
    send_file 'app/assets/files/Terms of Service VatOnWheels.pdf', :type=>"application/pdf", disposition: "inline"
 #   send_file(Rails.root.join("assets", "files", "Terms of Service VatOnWheels.pdf").to_s, :disposition => "inline")
   # send_file(
    #   "Terms of Service VatOnWheels.pdf",
    #filename: "Terms of Service VatOnWheels.pdf",
    #type: "application/pdf")
   # send_file view_context.asset_path 'Terms of Service VatOnWheels', :disposition => "inline"
  end
  
    
  
  
end
