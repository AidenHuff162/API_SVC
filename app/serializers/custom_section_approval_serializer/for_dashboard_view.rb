module CustomSectionApprovalSerializer
  class ForDashboardView < ActiveModel::Serializer
    attributes :id, :approval_chain_list, :requested_fields, :effective_date, :access_permission,
    :user, :custom_section_name, :request_sent, :expires_in, :status, :completed_date

    def user
      ActiveModelSerializers::SerializableResource.new(object.user, :serializer => UserSerializer::UpdatesPageCtus)
    end

    def approval_chain_list
      object.cs_approval_chain_list(true)
    end

    def custom_section_name
      object.section_name_mapper(object.custom_section.try(:section))
    end

    def status
      object&.state
    end

    def effective_date
      object['updated_at']&.to_date&.strftime(@instance_options[:company].get_date_format)
    end

    def completed_date
      object['updated_at']&.to_date&.strftime(@instance_options[:company].get_date_format)
    end

    def request_sent
      object['created_at'].to_date.strftime(@instance_options[:company].get_date_format)
    end

    def expires_in
      days = object.custom_section.try(:approval_expiry_time) - ((Time.now) - object.try(:created_at)).to_i / (24 * 60 * 60)
      "#{days} day".pluralize(days)
    end

    def requested_fields
      changed_fields = []
      default_fields = object.user.get_default_fields_values_against_requested_attributes(object.requested_fields)
      custom_fields = object.user.get_custom_fields_values_against_requested_attributes(object.requested_fields)
      default_fields[:new_values].pluck(:field_name).map { |name| changed_fields.push({custom_field_name: name}) } if default_fields && default_fields[:new_values]
      custom_fields[:new_values].pluck(:field_name).map { |name| changed_fields.push({custom_field_name: name}) } if custom_fields && custom_fields[:new_values]
      changed_fields
    end
  end
end
