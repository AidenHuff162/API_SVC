module SaplingApiService
  class ManageWorkflows
    attr_reader :company

    FILTERS = [ 'limit', 'page' ]

    def initialize(company)
      @company = company
    end

    def fetch_workflows(params)
      prepare_workflows_data_hash(params)
    end

    def show_workflow(params)
      return { message: 'Record not found', status: 404 } if Workstream.where(company_id: company.id, id: params[:id]).count < 1
      begin
        ws = Workstream.find_by(company_id: company.id, id: params[:id])
        ws_hash = { workflow: format_workflow_json(ws) }
        ws_hash.merge!(status: 200)
      rescue ActiveRecord::RecordNotFound => e
        return { message: 'Record not found', status: 404 }
      rescue ArgumentError => e
        return { message: 'Augment Error::Unprocessable Parameters' }
      rescue
        return { status: 500, message: 'Request failed' }
      end
    end

    def create_task_for_workflow(params)
      begin
        task = Task.create!(workstream_id: params[:workflow_id],
                    name: params[:name],
                    description: params[:description],
                    owner_id: User.find_by(guid: params[:owner_guid]).id,
                    task_type: params[:task_type],
                    deadline_in: params[:days_due],
                    time_line: format_timeline(params[:delayed_assignment]),
                    before_deadline_in: params[:delayed_assigment_days])
        return {status: '200',
                    task: [task.as_json]}
      rescue ActiveRecord::RecordNotFound => e
        return { message: 'Record not found', status: 404 }
      rescue ArgumentError => e
        return { message: 'Augment Error::Unprocessable Parameters' }
      rescue
        return { status: 500, message: 'Request failed' }
      end
    end

    def format_timeline(tl)
      if tl.downcase == 'yes'
        'immediately'
      elsif tl.downcase == 'no'
        'later'
      else 0
      end
    end

    def prepare_workflows_data_hash(params)
      if is_invalid_filters?(params)
        return { message: I18n.t("api_notification.invalid_filters"), status: 422 }
      end
      ws = Workstream.where(company_id: company.id)
      limit = (params[:limit].present? && params[:limit].to_i > 0) ? params[:limit].to_i : 50
      total_pages = (ws.count/limit.to_f).ceil

      if params[:page].to_i < 0 || total_pages < params[:page].to_i
        return { message: I18n.t("api_notification.invalid_page_offset"), status: 422 }
      end

      page = (ws.count <= 0) ? 0 : (!params[:page].present? || params[:page].to_i == 0 ? 1 : params[:page].to_i)
      workflow_data_hash = { current_page: page, total_pages: (ws.count <= 0) ? 0 : ((total_pages == 0) ? 1 : total_pages), total_workflows: ws.count, workflows: [] }

      if page > 0
        paginated_tasks = ws.paginate(:page => page, :per_page => limit)
        paginated_tasks.each do |ws|
          workflow_data_hash[:workflows].push format_workflow_json(ws)
        end
      end

      workflow_data_hash.merge!(status: 200)
    end

    def format_workflow_json(ws)
      {
        workflow_id: ws.id,
        workflow_name: ws.name,
        tasks_count: ws.tasks.count,
        created_at: ws.created_at,
        updated_at: ws.updated_at,
        deleted_at: ws.deleted_at
      }
    end

    def is_invalid_filters?(params, is_a_user = false)
      params.delete(:format)
      params.delete(:controller)
      params.delete(:action)
      params

      if is_a_user.present?
        return params.except(:id).count != 0
      else
        return !params.keys.to_set.subset?(FILTERS.to_set)
      end
    end
  end
end
