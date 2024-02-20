module PaperworkPacketSerializer
  class Description < ActiveModel::Serializer
    attributes :id, :name, :position, :packet_type, :description
  end
end
