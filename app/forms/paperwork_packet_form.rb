class PaperworkPacketForm < BaseForm
  presents :paperwork_packet

  PLURAL_RELATIONS = %i(paperwork_packet_connections)

  attribute :name, String
  attribute :description, String
  attribute :paperwork_packet_connections, Array[PaperworkPacketConnectionForm]
  attribute :company_id, Integer
  attribute :position, Integer
  attribute :packet_type, Integer
  attribute :user_id, Integer
  attribute :meta, JSON
  attribute :updated_by_id, Integer

  validates :name, :description, :company_id, presence: true
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)
  validates_format_of :description, with: Regexp.new(AvoidHtml::HTML_REGEXP, Regexp::MULTILINE)
end
