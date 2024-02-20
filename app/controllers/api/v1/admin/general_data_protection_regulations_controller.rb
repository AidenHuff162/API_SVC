module Api
  module V1
    module Admin
      class GeneralDataProtectionRegulationsController < BaseController
        authorize_resource

        def index
          regulation = current_company.general_data_protection_regulation
          if regulation.present?
            respond_with regulation, serializer: GeneralDataProtectionRegulationSerializer::Full, current_company: current_company
          else
            respond_with true
          end
        end

        def create
          save_and_respond_with_form
        end

        def update
          save_and_respond_with_form
        end

        private

        def save_and_respond_with_form
          form = GeneralDataProtectionRegulationForm.new general_data_protection_regulation_params
          form.save!
          respond_with form.record, serializer: GeneralDataProtectionRegulationSerializer::Full, current_company: current_company
        end

        def general_data_protection_regulation_params
          params.merge!(company_id: current_company.id, edited_by_id: current_user.id)
            .permit(:id, :company_id, :edited_by_id, :action_type, :action_period, :action_location => [])
        end
      end
    end
  end
end
