module DocumentPacketSerializer
  class Full < ActiveModel::Serializer
    type :paperwork_packet

    attributes :id, :name, :description, :paperwork_packet_connections, :position, :packet_type, :meta, :location_ids, :department_ids, :status_ids, :updated_at, :documents, :user_assigned_count
    has_many :paperwork_packet_connections, serializer: PaperworkPacketConnectionSerializer::Base
    belongs_to :user, serializer: UserSerializer::Basic
    belongs_to :updated_by, serializer: UserSerializer::Simple

    def location_ids
      if object.meta["location_id"].nil? || object.meta["location_id"] == ['all']
        ['all']
      else
        object.meta["location_id"].reject(&:blank?)
      end
    end

    def department_ids
      if object.meta["team_id"].nil? || object.meta["team_id"] == ['all']
        ['all']
      else
        object.meta["team_id"].reject(&:blank?)
      end
    end

    def status_ids
      if object.meta["employee_type"].nil? || object.meta["employee_type"] == ['all']
        ['all']
      else
        object.meta["employee_type"].reject(&:blank?)
      end
    end
  end
end
