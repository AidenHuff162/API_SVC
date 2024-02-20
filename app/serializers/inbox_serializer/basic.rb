module InboxSerializer
  class Basic < ActiveModel::Serializer
    type :email_template

    attributes :id, :email_type, :name, :updated_at,
               :template_edited_by, :editor, :location_ids, :department_ids, :is_default,
               :status_ids, :locations, :departments, :status, :schedule_options, :meta

    def template_edited_by
      object.editor.present? ? object.editor.display_name : ''
    end

    def editor
      object.get_editor
    end

    def email_type
      object.map_email_type
    end

    def locations 
      object.get_locations
    end
  end
end
