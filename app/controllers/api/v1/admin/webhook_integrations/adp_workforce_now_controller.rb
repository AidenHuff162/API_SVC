module Api
  module V1
    module Admin
      module WebhookIntegrations
        require 'oauth'
        require 'logger'
        require 'adp/connection'
        include ADPHandler

				class AdpWorkforceNowController < WebhookController

          before_action :current_company

	        include JsonResponder
	        respond_to :json
	        responders :json

					def job_titles_index
						if current_company.present?
							
							if current_company.integration_types.include?('adp_wfn_us') && current_company.integration_types.exclude?('adp_wfn_can')
								job_titles = current_company.job_titles.where.not(adp_wfn_us_code_value: nil).pluck(:name)
							elsif current_company.integration_types.include?('adp_wfn_can') && current_company.integration_types.exclude?('adp_wfn_us')
								job_titles = current_company.job_titles.where.not(adp_wfn_can_code_value: nil).pluck(:name)
							else
								job_titles = current_company.job_titles.where("adp_wfn_us_code_value IS NOT NULL OR adp_wfn_can_code_value IS NOT NULL").pluck(:name)
							end
						else
							job_titles = []
						end

						job_titles = job_titles.uniq
	          respond_with job_titles.to_json
					end
				end
			end
		end
	end
end
