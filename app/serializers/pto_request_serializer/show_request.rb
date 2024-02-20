module PtoRequestSerializer
  class ShowRequest < PtoRequestSerializer::Basic
    attributes :remaining_balance

    has_many :attachments, serializer: AttachmentSerializer

    def remaining_balance
      object.calculate_carryover_balance
    end
  end
end