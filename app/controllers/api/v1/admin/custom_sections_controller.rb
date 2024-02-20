module Api
  module V1
    module Admin
      class CustomSectionsController < BaseController
        load_and_authorize_resource only: :update
        authorize_resource only: [:index, :get_custom_sections]

        #TO-DO need to re-factor it when we need custom sections
        def index
          sections = []
          collection = CustomFieldsCollection.new(collection_params)
          custom_sections = [
            { section: 'additional_fields', name: 'Additional Information',
              help: 'All fields in this section are custom fields that can be added to each team member record. 
                     Use "Permissions" to customize this section’s visibility.', position: 0 },
            { section: 'personal_info', name: 'Personal Information',
              help: 'All fields in this section can be seen by the individual account owner, their manager, as well as
                     Sapling Admins.', position: 1 },
            { section: 'private_info', name: 'Private Information',
              help: 'All fields in this section are for confidential information only. Use "Permissions" to restrict 
                     this to only certain permission groups.', position: 2 },
            { section: 'profile', name: 'Public Information',
              help: 'All fields in this section can be seen by all team members, and are visible on every team member
                     profile.', position: 3 },
          ]

          custom_sections.try(:each) do |custom_section|
            custom_section[:custom_fields] = ActiveModelSerializers::SerializableResource.new(collection.results.where(section: CustomField.sections[custom_section[:section]]), each_serializer: CustomFieldSerializer::WithOptions)
            custom_section[:custom_section] = CustomSectionSerializer::Basic.new(current_company.custom_sections.find_by(section: custom_section[:section]))
          end
          respond_with custom_sections
        end

        def get_custom_sections
          respond_with current_company.custom_sections, each_serializer: CustomSectionSerializer::Basic
        end

        def webhook_page_index
          collection = CustomFieldsCollection.new(collection_params)
          custom_sections = [
            { section: 'profile', name: 'Public Information'},
            { section: 'personal_info', name: 'Personal Information'},
            { section: 'private_info', name: 'Private Information'},
            { section: 'additional_fields', name: 'Additional Information'}
          ]

          custom_sections.try(:each) do |custom_section|
            custom_section[:custom_fields] = ActiveModelSerializers::SerializableResource.new(collection.results.with_excluded_fields_for_webhooks.where(section: CustomField.sections[custom_section[:section]]), each_serializer: CustomFieldSerializer::ForWebhooks)
          end
          respond_with custom_sections
        end

        def update
          @custom_section.update!(update_custom_section_params)
          respond_with @custom_section, serializer: CustomSectionSerializer::Basic
        end

        def update_custom_section_params
          params.merge!(approval_chains_attributes: params[:approval_chains], company_id: current_company.id).permit(:id, :section, :is_approval_required, :approval_expiry_time, approval_chains_attributes: [:id, :approval_type, :_destroy, approval_ids: []])
        end

        private

        def collection_params
          params.merge(company_id: current_company.id)
        end
      end
    end
  end
end
