module CustomTableUserSnapshotSerializer
  class ForCreateUpdate < ActiveModel::Serializer
    attributes :id, :updated_by, :custom_snapshots, :updated_at, :created_at, :effective_date,
    :state, :request_state, :is_terminated, :terminated_data, :integration_type, :is_applicable, 
    :is_offboarded

    def updated_by
      object.edited_by.try(:display_name)
    end

    def custom_snapshots
      ActiveModelSerializers::SerializableResource.new(object.custom_snapshots.includes(:custom_field), each_serializer: CustomSnapshotSerializer::ForInfo, company: @instance_options[:company])
    end

    def is_offboarded
      object.terminated_data.present? && object.user.departed?
    end
  end
end
