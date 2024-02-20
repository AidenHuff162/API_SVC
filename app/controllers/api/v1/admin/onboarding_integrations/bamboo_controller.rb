module Api
  module V1
    module Admin
      module OnboardingIntegrations
        class BambooController < BaseController

          def job_title_index
            respond_with ::HrisIntegrationsService::Bamboo::JobTitle.new(current_company).fetch.to_json
          end

          def create_job_title
            if params[:title].present?
              ::HrisIntegrations::Bamboo::CreateBambooJobTitleFromSaplingJob.perform_later(current_company, params[:title])
            end
            return render json: false
          end

          def create
            if current_company.id != 64
              ::HrisIntegrations::Bamboo::UpdateSaplingUsersFromBambooJob.perform_later(current_company.id, true)
            end
            return render json: false
          end
        end
      end
    end
  end
end
