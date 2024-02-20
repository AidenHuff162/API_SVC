module Api
  module V1
    module Admin
      class CustomFieldOptionsController < BaseController
        authorize_resource

        def create
          save_and_respond_with_form
        end

        def update
          save_and_respond_with_form
        end
        
        def destroy
          option = CustomFieldOption.joins(:custom_field).where(custom_fields: {company_id: current_company.id}, id: params[:id]).take if params[:id]
          option.destroy if option
          head 204
        end

        private

        def save_and_respond_with_form
          form = CustomFieldOptionForm.new params
          form.save!
          respond_with form, serializer: CustomFieldOptionSerializer::CustomGroup
        end
      end
    end
  end
end
