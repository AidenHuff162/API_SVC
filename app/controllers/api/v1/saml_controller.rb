module Api
  module V1
		class SamlController < ApiController
			include SAMLSettings

			def init
		    request = OneLogin::RubySaml::Authrequest.new
        if current_company.get_saml_sso_target_url.present? && current_company.get_saml_idp_cert.present?
		      redirect_to(request.create(saml_settings))
        else
          redirect_to "https://#{current_company.app_domain}/#/login?error=Missing configurations"
        end
		  end

		end
	end
end
