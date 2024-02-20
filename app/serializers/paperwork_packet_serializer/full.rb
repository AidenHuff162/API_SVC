module PaperworkPacketSerializer
  class Full < ActiveModel::Serializer
    type :paperwork_packet

    attributes :id, :name, :description, :paperwork_packet_connections, :position, :packet_type, :meta, :locations, :departments, :status, :updated_at, :documents, :user_assigned_count
    has_many :paperwork_packet_connections, serializer: PaperworkPacketConnectionSerializer::Base
    belongs_to :user, serializer: UserSerializer::Basic
    belongs_to :updated_by, serializer: UserSerializer::Simple

    def locations
      if object.meta["location_id"] == ['all']
        ['all']
      else
        Company.find(object.company_id).locations.where(id: object.meta["location_id"])
      end
    end

    def departments
      if object.meta["team_id"] == ['all']
        ['all']
      else
        Company.find(object.company_id).teams.where(id: object.meta["team_id"])
      end
    end

    def status
      if object.meta["employee_type"] == ['all']
        ['all']
      else
        Company.find(object.company_id).custom_fields.find_by(field_type: CustomField.field_types[:employment_status]).custom_field_options.where(option: object.meta["employee_type"])
      end
    end
  end
end
