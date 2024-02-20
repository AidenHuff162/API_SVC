module CustomTableSerializer
  class CustomTableForInfo < ActiveModel::Serializer
    attributes :id, :name, :position, :table_type, :custom_table_user_snapshots, :count, :custom_table_property, :custom_fields, :is_approval_required, :approval_type, :approval_ids, :approval_expiry_time, :expiry_date, :approval_chains

    def count
      object.custom_table_user_snapshots.where(user_id: @instance_options[:user_id]).count
    end

    def custom_table_user_snapshots
      table_user_snapshots = object.custom_table_user_snapshots.where(user_id: @instance_options[:user_id])
      ActiveModelSerializers::SerializableResource.new(table_user_snapshots, each_serializer: CustomTableUserSnapshotSerializer::ForInfo, company: object.company) if table_user_snapshots
    end

    def custom_fields
      ActiveModelSerializers::SerializableResource.new(object.custom_fields, each_serializer: CustomFieldSerializer::BasicWithOptions, user_id: @instance_options[:user_id])
    end

    def expiry_date
      Date.today + object.approval_expiry_time if object.approval_expiry_time.present?
    end

    def approval_chains
      ActiveModelSerializers::SerializableResource.new(object.approval_chains, each_serializer: ApprovalChainSerializer::Basic, company: object.company_id)
    end

  end
end
