module TaskUserConnectionSerializer
  class UpdateWithCount < Base
    attributes :completed_at, :completed_tasks_count, :incomplete_tasks_count, :overdue_tasks_count, :pending_tasks_count

    def completed_at
      object.completed_at
    end
    
    def pending_tasks_count
      params = {
        count: true,
        state: 'in_progress',
        pending: true,
        not_pending: false,
        company_id: @instance_options[:company_id]
      }

      params.merge!(workstream_id: object.task.workstream_id) if scope[:workstream_filter]

      count = nil
      if @instance_options[:get_user_count]
        params[:user_id] = object.user_id
        count = TaskUserConnectionsCollection.new(params).results

      elsif @instance_options[:get_owner_count]
        params[:owner_id] = object.owner_id
        count = TaskUserConnectionsCollection.new(params).results
      end

      count
    end

    def completed_tasks_count
      params = {
        count: true,
        state: 'completed',
        not_pending: true,
        company_id: @instance_options[:company_id]
      }

      params.merge!(workstream_id: object.task.workstream_id) if scope[:workstream_filter]

      count = nil
      if @instance_options[:get_user_count]
        params[:user_id] = object.user_id
        count = TaskUserConnectionsCollection.new(params).results

      elsif @instance_options[:get_owner_count]
        params[:owner_id] = object.owner_id
        count = TaskUserConnectionsCollection.new(params).results
      end

      count
    end

    def incomplete_tasks_count
      params = {
        count: true,
        state: 'in_progress',
        not_pending: true,
        company_id: @instance_options[:company_id]
      }

      params.merge!(workstream_id: object.task.workstream_id) if scope[:workstream_filter]

      count = nil
      if @instance_options[:get_user_count]
        params[:user_id] = object.user_id
        count = TaskUserConnectionsCollection.new(params).results

      elsif @instance_options[:get_owner_count]
        params[:owner_id] = object.owner_id
        count = TaskUserConnectionsCollection.new(params).results
      end

      count
    end

    def overdue_tasks_count
      params = {
        count: true,
        state: 'in_progress',
        overdue: true,
        not_pending: true,
        company_id: @instance_options[:company_id]
      }

      params.merge!(workstream_id: object.task.workstream_id) if scope[:workstream_filter]

      count = nil
      if @instance_options[:get_user_count]
        params[:user_id] = object.user_id
        count = TaskUserConnectionsCollection.new(params).results

      elsif @instance_options[:get_owner_count]
        params[:owner_id] = object.owner_id
        count = TaskUserConnectionsCollection.new(params).results
      end

      count
    end
  end
end
