module Api
  module V1
    module Admin
      class ProfileTemplatesController < BaseController

        load_and_authorize_resource

        def index
          collection = ProfileTemplatesCollection.new(profile_template_params)
          if profile_template_params[:bulk_onboarding]
            respond_with collection.results.order(:id), each_serializer: ProfileTemplateSerializer::BulkOnboarding
          elsif profile_template_params[:profile_page]
            respond_with collection.results.order(:id), each_serializer: ProfileTemplateSerializer::ProfilePage
          elsif profile_template_params[:process_type]
            respond_with collection.results.order(:id), each_serializer: ProfileTemplateSerializer::Full
          else
            respond_with collection.results.order(:id), each_serializer: ProfileTemplateSerializer::Base
          end
        end

        def show
          respond_with @profile_template, serializer: ProfileTemplateSerializer::Full
        end

        def create
          template = ProfileTemplate.new(profile_template_params)
          template.save!
          respond_with template, serializer: ProfileTemplateSerializer::Base
        end

        def update
          @profile_template.delete_removed_connections(profile_template_params[:profile_template_custom_table_connections_attributes], profile_template_params[:profile_template_custom_field_connections_attributes])
          @profile_template.update!(profile_template_params)
          respond_with @profile_template, serializer: ProfileTemplateSerializer::Full
        end

        def destroy
          @profile_template.destroy!
          head :no_content
        end

        def duplicate
          new_template = @profile_template.duplicate(current_company)
          respond_with new_template, serializer: ProfileTemplateSerializer::Base
        end

        private

        def profile_template_params
          params.permit(:name, :process_type_id, :process_type, :bulk_onboarding, :profile_page, profile_template_custom_field_connections_attributes: [:id, :position, :required, :custom_field_id, :default_field_id], profile_template_custom_table_connections_attributes: [:id, :position, :custom_table_id]).merge(company_id: current_company.id, edited_by_id: current_user.id, meta: params[:meta])
        end

      end
    end
  end
end
