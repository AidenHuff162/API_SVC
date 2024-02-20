module CustomTableUserSnapshotSerializer
  class ForDashboard < ActiveModel::Serializer
    type :custom_table_user_snapshot

    attributes :id, :custom_table_name, :expire_time, :effective_date, :user, :requested_date, :next_approver, :status, :completed_date

    def user
      ActiveModelSerializers::SerializableResource.new(User.find_by(id: object['user_id']), :serializer => UserSerializer::UpdatesPageCtus)
    end

    def next_approver
      ctus = CustomTableUserSnapshot.find_by(id: object['id'])
      ctus.find_next_approver if ctus.present?
    end

    def requested_date
      object['request_date'].to_date.strftime(@instance_options[:company].get_date_format) if object['request_date'].present?
    end

    def effective_date
      object['effect_date'].to_date.strftime(@instance_options[:company].get_date_format) if object['effect_date'].present?
    end

    def completed_date
      object['updated_at']&.to_date&.strftime('%b %d,%Y')
    end

    def read_attribute_for_serialization(attr)
      if object.key? attr.to_s
        attr.to_s == 'meta' ? JSON.parse(object['meta']) : object[attr.to_s]
      else
        self.send(attr) rescue nil
      end
    end
  end
end
