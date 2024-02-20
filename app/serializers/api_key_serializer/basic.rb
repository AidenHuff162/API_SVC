module ApiKeySerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :name, :key, :edited_by, :created_at, :expires_in

    def edited_by
      object.edited_by&.display_name
    end

    def key
      forty_staric = "*" * 40
      "#{forty_staric}#{object.key.try(:last, 4)}"
    end
  end
end
