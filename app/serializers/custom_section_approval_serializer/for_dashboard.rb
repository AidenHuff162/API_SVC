module CustomSectionApprovalSerializer
  class ForDashboard < ActiveModel::Serializer
    type :custom_section_approval

    attributes :id, :custom_section_name, :expire_time, :user, :effective_date, :requested_date, :next_approver, :status, :completed_date, :preferred_name

    def requested_by
      @instance_options[:company].users.find_by(id: object['user_id']).try(:display_name)
    end

    def requested_date
      object['request_date'].to_date.strftime(@instance_options[:company].get_date_format) if object['request_date'].present?
    end

    def effective_date
      object['effect_date'].to_date.strftime(@instance_options[:company].get_date_format) if object['effect_date'].present?
    end

    def user
       ActiveModelSerializers::SerializableResource.new(User.find_by(id: object['user_id']), :serializer => UserSerializer::UpdatesPageCtus)
    end

    def expire_time
      object.custom_section.try(:approval_expiry_time) - ((Time.now) - object.try(:created_at)).to_i / (24 * 60 * 60) if object.custom_section.is_approval_required.present?
    end

    def is_custom_section_approval
      return true
    end

    def status
      object.state
    end

    def next_approver
      csa = CustomSectionApproval.find_by(id: object['id'])
      csa.find_next_approver if csa.present?
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
