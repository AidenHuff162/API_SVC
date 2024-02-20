module CustomTables
  class PowerUpdate
    attr_reader :params, :current_user, :current_company

    def initialize(params, current_user, current_company)
      @params = params
      @current_user = current_user
      @current_company = current_company
      @response = 200
    end

    def perform
      set_activities_nested_attributes
      CustomTables::PowerUpdateWorker.perform_async(@params, @current_user.get_first_name, @current_user.company.name, @current_user.company_id, @current_user.get_email, @current_user.id)
      @response
    end

    private

    def set_activities_nested_attributes
      @params.each do |param_object|
        param_object["activities_attributes"] = []
        param_object["activities_attributes"].push(get_activity_object(param_object))
      end
    end 

    def get_activity_object param_object
      actvity_attribute_object = {}
      actvity_attribute_object["agent_id"] = @current_user.id
      actvity_attribute_object["description"] = I18n.t("admin.people.profile_setup.roles.custom_table_user_snapshot_activities.common_bulk_activity", table_name: get_table_name(param_object["custom_table_id"]))
      actvity_attribute_object
    end

    def get_table_name table_id
      @current_company.custom_tables.find(table_id).try(:name)
    end

  end
end