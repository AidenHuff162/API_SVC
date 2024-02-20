module ActivitySerializer
  class ForUpdatesCtus < ActiveModel::Serializer
    attributes :description, :created_at, :total_entries
    belongs_to :agent, serializer: UserSerializer::History

    def total_entries
      instance_options[:total_entries]
    end
  end
end
