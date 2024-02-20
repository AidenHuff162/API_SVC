module PaperworkPacketSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :name, :position, :packet_type
  end
end
