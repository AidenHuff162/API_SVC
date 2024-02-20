module CustomTableUserSnapshotSerializer
  class ForDashboardView < ActiveModel::Serializer
    attributes :id, :changed_snapshots, :approval_chain_list, :effective_date, 
    :user, :custom_table_name, :request_sent, :expires_in, :access_permission, :status, :completed_date

    def user
      ActiveModelSerializers::SerializableResource.new(object.user, :serializer => UserSerializer::UpdatesPageCtus)
    end

    def approval_chain_list
      object.approval_chain_list(false)
    end

    def custom_table_name
      object.custom_table.try(:name)
    end

    def status
      object&.request_state
    end

    def completed_date
      object['updated_at']&.to_date&.strftime(@instance_options[:company].get_date_format)
    end

    def request_sent
      object['created_at'].to_date.strftime(@instance_options[:company].get_date_format)
    end

    def expires_in
      days = object.custom_table.try(:approval_expiry_time) - ((Time.now) - object.try(:created_at)).to_i / (24 * 60 * 60)
      "#{days} day".pluralize(days)
    end
  end
end
