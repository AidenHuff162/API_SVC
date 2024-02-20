module CompanySerializer
  class PreboardWelcome < ActiveModel::Serializer
    attributes :id, :name, :welcome_note, :custom_tables_count,  :welcome_section

    has_one :operation_contact, serializer: UserSerializer::Owner

    def custom_tables_count
      object.get_cached_custom_tables_count
    end
  end
end
