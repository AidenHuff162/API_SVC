class LinkedinLoginController < ApplicationController

  def onboard
    encrypted_data = encrypt_data params.to_h
    render 'api/v1/login/onboard', locals: { error: '', data: encrypted_data }
  end

  def verify_domain
    begin
      if params['object'].blank?
        render file: 'public/404.html'
        return
      end
      
      if params[:subdomain]
        params[:subdomain].strip!
        company = Company.where("subdomain ILIKE ? ", params[:subdomain]).take
        
        if company.blank?
          render 'api/v1/login/onboard', locals: { error: 'company_not_found', data: params['object']['data'] }
        else
          integration = find_integration company 
          if integration.blank?
            render 'api/v1/login/onboard', locals: { error: 'integration_not_found', data: params['object']['data'] }
            return
          end
          subdomain = encrypt_data({payload: company.subdomain})
          redirect_to "http://#{params[:subdomain]}.ngrok.io/api/v1/webhook/linked_in/onboard?data=#{params['object']['data']}&subdomain=#{subdomain}" if Rails.env == "development"
          redirect_to "https://" + company.subdomain + ".saplingapp.io/api/v1/webhook/linked_in/onboard?data=#{params['object']['data']}&subdomain=#{subdomain}" if Rails.env == 'production'
        end
      else
        render 'api/v1/login/onboard', locals: { error: 'company_not_found', data: params['object']['data'] }
      end
    rescue 
      render file: 'public/404.html'
    end
  end

  private
  
  def find_integration company
    integration = company.integration_instances.find_by(api_identifier: 'linked_in', state: :active)
  end 
  
  def encrypt_data data
    JsonWebToken.encode(data)
  end
end
