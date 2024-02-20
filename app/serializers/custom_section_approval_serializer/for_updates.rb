module CustomSectionApprovalSerializer
  class ForUpdates < ActiveModel::Serializer
    attributes :custom_section_name, :requested_by, :requested_date, :user, :expiry_days_left, :is_custom_section_approval, :current_approver_data

    def updated_by
      object.requester_id.try(:full_name)
    end

    def custom_section_name
      object.section_name_mapper(object.custom_section.try(:section))
    end

    def requested_by
      object.custom_section.company.users.find_by(id: object.requester_id).try(:display_name)
    end

    def requested_date
      object.try(:created_at).to_date.strftime(object.custom_section.try(:company).get_date_format)
    end

    def user
      ActiveModelSerializers::SerializableResource.new(object.user, :serializer => UserSerializer::UpdatesPageCtus)
    end

    def expiry_days_left
      object.custom_section.try(:approval_expiry_time) - ((Time.now) - object.try(:created_at)).to_i / (24 * 60 * 60) if object.custom_section.is_approval_required.present?
    end

    def is_custom_section_approval
      return true
    end

    def current_approver_data
      object.approvers
    end
  end
end
