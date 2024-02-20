require 'gsuite/google_api_authorizer'

module Api
module V1
	module	Admin
		class GsuiteAccountsController < ApiController
			# before_action :get_authorizer
			before_action :set_base_url

			APPLICATION_NAME = 'Sapling Gsuite'

			def get_gsuite_auth_credential
				service = Google::Apis::AdminDirectoryV1::DirectoryService.new
				service.client_options.application_name = APPLICATION_NAME
				service.authorization = authorize
			end

			def authorize
				get_authorizer(current_company)
				credentials = @authorizer.get_credentials_from_relation(current_company,current_company.id)
				logger.info credentials
				if credentials.nil?
				  logger.info("GsuiteAccountsController::authorize GCP not present in relation")	
				  url = @authorizer.get_authorization_url(base_url: @base_url,state: current_company.id)
				  redirect_to url
				else
				  logger.info("GsuiteAccountsController::authorize GCP present in relation")
				  if Rails.env == "development"
				    redirect_to "http://#{current_company.app_domain}/#/admin/settings/integrations?goauthres=Account already authorized"
				  else
					redirect_to "https://" + current_company.app_domain + "/#/admin/settings/integrations?goauthres=Account already authorized"
				  end
				end
			end

			def oauth2callback
			  company = Company.find(params[:state].to_i)
			  if params[:code].present?					
					get_authorizer(company)
			    credentials = @authorizer.get_and_store_credentials_from_code_relation(company, user_id: company.id, code: params[:code], base_url: @base_url) 
				
				if company.get_gsuite_account_info.present?
					company.get_gsuite_account_info.integration_credentials.find_by(name: 'Gsuite Auth Credentials Present').update(value: true)
					create_integration_api_logging(company, 'GSuite', 'OAuth', 'N/A', {result: params.to_s}, 200)

					res= "Successfully authroized with GSuite"
				else
					res= "Unable to authorize an unexpected error occurred"
					create_integration_api_logging(company, 'GSuite', 'OAuth', 'N/A', {error: params.to_s}, 500)
				end
					
			  else
			    res= "Authorization Code is Missing"
					create_integration_api_logging(company, 'GSuite', 'OAuth', 'N/A', {error: params.inspect}, 500)
			  end

			  if Rails.env == "development"
					redirect_to "http://" + company.app_domain + "/#/admin/settings/integrations?goauthres=#{res}"
			  else
					redirect_to "https://" + company.app_domain + "/#/admin/settings/integrations?goauthres=#{res}"
			  end
			end

			def remove_credentials
			  if params[:company_id].present?
					company = Company.find_by(id: params[:company_id].to_i)
					get_authorizer(company)
					if @authorizer.get_credentials_from_relation(company, company.id.to_i).present?
						res = @authorizer.revoke_authorization_from_relation(company, company.id.to_i)
						if company.get_gsuite_account_info.present?
						  company.get_gsuite_account_info.integration_credentials.find_by(name: 'Gsuite Auth Credentials Present').update(value: false)
						  create_integration_api_logging(company, 'GSuite', 'Remove Credentials', 'N/A', {result: res.to_s}, 200)
						  status  = 200
						end
						logger.info "GsuiteAccountsController::remove_credentials Removed!!" 
					end	 
					respond_with current_company.integrations, each_serializer: IntegrationSerializer::Full
			  else
					respond_with :nothing, status: 404	
			  end
			end

			def get_authorizer(company)
				if company.present?
					auth_lib_obj = Gsuite::GoogleApiAuthorizer.new
					@authorizer = auth_lib_obj.get_authorizer(company)
				end
			end

			def set_base_url
				@base_url = request.host.include?("saplingapp.io") ? "https://www.saplingapp.io/api/v1/oauth2callback" : "https://#{request.host}/api/v1/oauth2callback"
			end

		end
	end
end
end
