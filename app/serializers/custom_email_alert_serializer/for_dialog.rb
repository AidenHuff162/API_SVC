module CustomEmailAlertSerializer
  class ForDialog < ActiveModel::Serializer
    attributes :id, :title, :subject, :applied_to_teams, :applied_to_locations, :applied_to_statuses, :updated_at,
      :alert_type, :notified_to, :individuals, :notifiers, :body

    def notifiers
      object.notifiers.reject(&:blank?)
    end

    def individuals
      if object.notified_to == 'individual'
        individuals = ActiveModelSerializers::SerializableResource.new(object.company.users.where(id: object.notifiers), each_serializer: UserSerializer::CustomAlertNotifier)
      end
    end
  end
end
