module UserSerializer
  class PeoplePage < ActiveModel::Serializer
    type :user

    attributes :id, :full_name, :first_name, :last_name, :preferred_name, :picture, :title, :email, :team_name, :location_name, :location_id,
               :team_id, :preferred_full_name, :pending_pto_requests, :manager, :onboarding_profile_template,
               :employee_type, :termination_date, :buddy
    has_one :profile, serializer: ProfileSerializer::Permitted

    def title
      object.title.gsub('&amp;amp;', '&') if object.title.present?
    end

    def full_name
      object.preferred_full_name
    end

    def team_name
      object.get_team_name if !scope[:pto_request]
    end

    def location_name
      object.get_location_name if !scope[:pto_request]
    end

    def manager
      if !scope[:pto_request] && object.manager.present?
        ActiveModelSerializers::SerializableResource.new(object.manager, serializer: UserSerializer::PeopleManager)
      end
    end

    def pending_pto_requests
      if scope[:pto_request] && object.company.enabled_time_off
        pto_requests = object.pto_requests.pending_requests.where(partner_pto_request_id: nil)
        ActiveModelSerializers::SerializableResource.new(pto_requests, each_serializer: PtoRequestSerializer::ShowRequest) if pto_requests.present?
      end
    end

    def onboarding_profile_template
      if scope[:pto_request] && object.onboarding_profile_template
        ActiveModelSerializers::SerializableResource.new(object.onboarding_profile_template, serializer: ProfileTemplateSerializer::WithConnections)
      else
        nil
      end
    end

    def termination_date
      object.try(:termination_date).to_date.strftime(object.try(:company).get_date_format) if object.termination_date && object.permission_service.onlyCheckPeoplePageVisibility(scope[:current_user])
    end

    def email
      object.email.present? ? object.email : object.personal_email
    end
  end
end
