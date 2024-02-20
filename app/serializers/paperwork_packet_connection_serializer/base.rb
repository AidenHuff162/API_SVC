module PaperworkPacketConnectionSerializer
  class Base < ActiveModel::Serializer
    attributes :id, :connectable_id, :connectable_type, :paperwork_packet_id, :is_cosigned

    def is_cosigned
      if object.connectable_type == 'PaperworkTemplate'
        return object.connectable.representative_id.present? || object.connectable.is_manager_representative.present?
      end
      false
    end

  end
end
