module TaskSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :name, :description, :workstream_id, :owner_id , :deadline_in, :position,
               :task_type, :_selected, :before_deadline_in, :time_line, :workspace_id, :sanitized_name,
               :custom_field_id, :task_coworker, :task_schedule_options, :survey_id, :dependent_tasks,
               :token_name, :token_description

    belongs_to :owner, class_name: 'User', serializer: UserSerializer::Short
    belongs_to :workspace, serializer: WorkspaceSerializer::Onboard
    belongs_to :custom_field, serializer: CustomFieldSerializer::Basic

    def _selected
      true
    end
    
    def name
      Nokogiri::HTML(object.name).xpath("//*[p]").first.content rescue " "
    end

    def description
      Nokogiri::HTML(object.description).xpath("//*[p]").first.content rescue " "
    end

    def owner
    	object.owner
    end

    def task_coworker
      if !object.custom_field.nil?
        custom_field_value = object.custom_field.custom_field_values.where(user_id: @instance_options[:user_id].to_i).first
        if !custom_field_value.nil?
          custom_field_value.coworker
        end
      end
    end

    def token_name
      object.name rescue ''
    end

    def token_description
      object.description rescue ''
    end
  end
end
