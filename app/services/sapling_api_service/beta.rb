module SaplingApiService
  class Beta
    attr_reader :company, :request, :token, :api_key_fields

    delegate :fetch_meta_data, to: :profile_setup
    delegate :fetch_users_with_specific_data, :fetch_users, :fetch_user, :fetch_user_for_ids_server, to: :reterieve_user_profile
    delegate :fetch_tasks, to: :reterieve_tasks
    delegate :fetch_workflows, :show_workflow, :create_task_for_workflow, to: :manage_workflows
    delegate :update_user, :create_user, to: :save_user_profile
    delegate :create_pending_hire, :update_pending_hire, to: :save_pending_hire_profile
    delegate :fetch_pending_hires, :fetch_pending_hire, to: :reterieve_pending_hire_profile
    delegate :fetch_countries, :fetch_states, to: :retrieve_address
    delegate :fetch_group_fields, to: :retrieve_group_fields

    def initialize(company, api_meta_data)
      @company = company
      @request = api_meta_data[:request]
      @token = api_meta_data[:token]
      @api_key_fields = api_meta_data[:api_key_fields]
    end

    def manage_workflows_index_route_data(params)
      fetch_workflows(params)
    end

    def create_workflow_task(params)
      create_task_for_workflow(params)
    end

    def manage_workflows_show_route_data(params)
      show_workflow(params)
    end

    def manage_profile_fields_route_data(params = nil)
      params[:id].present? ? fetch_users_with_specific_data(params, api_key_fields) : fetch_meta_data
    end

    def manage_profile_index_route_data(params)
      fetch_users(params, api_key_fields)
    end

    def manage_tasks_index_route_data(params)
      fetch_tasks(params)
    end

    def manage_profile_show_route_data(params)
      fetch_user(params, api_key_fields)
    end

    def manage_profile_update_route_data(params)
      update_user(params)
    end

    def manage_profile_create_route_data(params)
      create_user(params)
    end

    def manage_pending_hire_create_route_data(params)
      create_pending_hire(params.to_hash)
    end

    def manage_pending_hire_update_route_data(params)
      update_pending_hire(params.to_hash)
    end

    def manage_pending_hire_show_route_data(params)
      fetch_pending_hire(params)
    end

    def manage_pending_hire_index_route_data(params)
      fetch_pending_hires(params)
    end

    def manage_webhooks_routes(action, params)
      manage_webhooks(action, params)
    end

    def manage_countries_data(params)
      fetch_countries(params)
    end

    def manage_states_data(params)
      fetch_states(params)
    end

    def manage_get_sapling_profile_route_data(params)
      fetch_user_for_ids_server(params, api_key_fields)
    end

    def manage_group_fields_route_data(params)
      fetch_group_fields(params)
    end

    private

    def manage_webhooks(action, params)
      SaplingApiService::WebhookServices::ManageWebhookService.new(company, request, token, params, action).perform
    end

    def manage_workflows
      SaplingApiService::ManageWorkflows.new company
    end

    def profile_setup
      SaplingApiService::ProfileSetup.new company
    end

    def reterieve_user_profile
      SaplingApiService::RetrieveUserProfile.new company
    end

    def reterieve_tasks
      SaplingApiService::RetrieveTasks.new company
    end

    def save_user_profile
      SaplingApiService::SaveUserProfile.new company, request, token
    end

    def reterieve_pending_hire_profile
      SaplingApiService::RetrievePendingHireProfile.new company, request, token
    end

    def save_pending_hire_profile
      SaplingApiService::SavePendingHireProfile.new company, request, token
    end

    def retrieve_address
      SaplingApiService::RetrieveAddress.new company, request, token
    end

    def retrieve_group_fields
      SaplingApiService::RetrieveGroupFields.new company
    end
  end
end
