module ProfileTemplateSerializer
  class Base < ActiveModel::Serializer
    attributes :id, :name, :edited_by_name, :meta, :process_type_id, :updated_at, :field_count,
               :location_names, :team_names, :status_names, :users_count

  end
end
