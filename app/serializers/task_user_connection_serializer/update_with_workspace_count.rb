module TaskUserConnectionSerializer
  class UpdateWithWorkspaceCount < Base
    attributes :complete_tasks_count, :open_tasks_count, :overdue_tasks_count, :assigned_tasks_count

    def complete_tasks_count
      params = {
        count: true,
        state: 'completed',
        task_page: 'workspace',
        workspace_id: @instance_options[:workspace_id],
        company_id: @instance_options[:company_id]
      }
      TaskUserConnectionsCollection.new(params).results
    end

    def assigned_tasks_count
      params = {
        count: true,
        state: 'in_progress',
        task_page: 'workspace',
        status: 'assigned',
        workspace_id: @instance_options[:workspace_id],
        company_id: @instance_options[:company_id]
      }
      TaskUserConnectionsCollection.new(params).results
    end

    def open_tasks_count
      params = {
        count: true,
        state: 'in_progress',
        task_page: 'workspace',
        status: 'open',
        workspace_id: @instance_options[:workspace_id],
        company_id: @instance_options[:company_id]
      }
      TaskUserConnectionsCollection.new(params).results
    end

    def overdue_tasks_count
      params = {
        count: true,
        state: 'in_progress',
        task_page: 'workspace',
        status: 'overdue',
        workspace_id: @instance_options[:workspace_id],
        company_id: @instance_options[:company_id]
      }
      TaskUserConnectionsCollection.new(params).results
    end
  end
end
