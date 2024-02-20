module CustomTableUserSnapshotSerializer
  class ForUpdates < ActiveModel::Serializer
    attributes :custom_table_name, :requested_by, :requested_date, :user, :expiry_days_left, :current_approver_data

    def updated_by
      object.edited_by.try(:full_name)
    end

    def custom_table_name
      object.custom_table.try(:name)
    end

    def requested_by
      object.custom_table.company.users.find_by(id: object.requester_id).try(:display_name)
    end

    def requested_date
      object.try(:created_at).to_date.strftime(object.custom_table.try(:company).get_date_format)
    end

    def user
      ActiveModelSerializers::SerializableResource.new(object.user, :serializer => UserSerializer::UpdatesPageCtus)
    end

    def expiry_days_left
      object.custom_table.try(:approval_expiry_time) - ((Time.now) - object.try(:created_at)).to_i / (24 * 60 * 60) if object.custom_table.is_approval_required.present?
    end

    def current_approver_data
      object.approvers
    end
  end
end
