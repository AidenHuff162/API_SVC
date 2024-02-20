module UserSerializer
  class UserPilotInformation < ActiveModel::Serializer
    attributes :id, :display_name, :first_name, :last_name, :start_date, :title, :email, :personal_email, :created_at,
      :created_by_source, :current_stage, :guid, :last_active, :role, :sign_in_count, :start_date, :super_user, :uid,
      :notifications

    def notifications
      #sending company information as an notifcation so that user can't gess the original relation with table
      ActiveModelSerializers::SerializableResource.new(object.company, serializer: CompanySerializer::UserPilotInformation)
    end
  end
end
