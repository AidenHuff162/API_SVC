class PaperworkPacketConnectionForm < BaseForm
  presents :paperwork_packet_connection

  attribute :connectable_id, Integer
  attribute :connectable_type, String
  attribute :paperwork_packet_id, Integer
end
