module SaplingApiService
  class RetrieveTasks
    attr_reader :company
    require 'nokogiri'

    FILTERS = [ 'limit', 'page', 'owner_email', 'state', 'overdue', 'upcoming']

    def initialize(company)
      @company = company
    end

    def fetch_tasks(params)
      prepare_tasks_data_hash(params)
    end

    def prepare_tasks_data_hash(params)
      if is_invalid_filters?(params)
        return { message: I18n.t("api_notification.invalid_filters"), status: 422 }
      elsif params[:owner_email] && !User.find_by(email: params[:owner_email])
        return { message: 'No owner found with this email', status: 404 }
      end
      tuc = TaskUserConnection.joins("INNER JOIN tasks ON tasks.id = task_user_connections.task_id").joins("INNER JOIN workstreams ON workstreams.id = tasks.workstream_id").where(workstreams: {company_id: company.id})
      tuc = filter_tuc(tuc, params)
      limit = (params[:limit].present? && params[:limit].to_i > 0) ? params[:limit].to_i : 50
      total_pages = (tuc.count/limit.to_f).ceil

      if params[:page].to_i < 0 || total_pages < params[:page].to_i
        return { message: I18n.t("api_notification.invalid_page_offset"), status: 422 }
      end

      page = (tuc.count <= 0) ? 0 : (!params[:page].present? || params[:page].to_i == 0 ? 1 : params[:page].to_i)
      tasks_data_hash = { current_page: page, total_pages: (tuc.count <= 0) ? 0 : ((total_pages == 0) ? 1 : total_pages), total_tasks: tuc.count, tasks: [] }

      if page > 0
        paginated_tasks = tuc.paginate(:page => page, :per_page => limit)
        paginated_tasks.each do |tuc|
          tasks_data_hash[:tasks].push format_task_json(tuc)
        end
      end

      tasks_data_hash.merge!(status: 200)
    end

    def format_task_json(tuc)
      {
        workflow_id: tuc.task.workstream_id,
        workflow_name: tuc.task.workstream&.name,
        task_id: tuc.id,
        name: Nokogiri::HTML(ReplaceTokensService.new.replace_task_tokens(tuc.task.name, tuc.user)).text,
        workspace_name: tuc.workspace&.name,
        description: Nokogiri::HTML(ReplaceTokensService.new.replace_task_tokens(tuc.task.description, tuc.user)).text,
        created_at: tuc.created_at,
        updated_at: tuc.updated_at,
        owner_guid: tuc.workspace? ? tuc.workspace_id : tuc.owner&.guid,
        owner_email: tuc.workspace? ? tuc.workspace.associated_email : tuc.owner&.email ,
        owner_name: get_owner_name(tuc),
        receiver_guid: tuc.user&.guid,
        receiver_email: get_user_email(tuc.user),
        receiver_name: tuc.user&.preferred_full_name,
        due_date: tuc.due_date,
        state: tuc.state
      }
    end

    def get_user_email(user)
      if user.email
        user.email
      elsif user.personal_email
        user.personal_email
      else
        nil
      end
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

    def filter_tuc(tuc, params)
      filtered_tuc =  tuc.joins(:user).where("users.super_user = 'false'")
      if params[:owner_email]
        if User.find_by(email: params[:owner_email])
          filtered_tuc = tuc.joins(:owner).where(users: {email: params[:owner_email]})
        else
          filtered_tuc = tuc.joins(:owner).where(users: {personal_email: params[:owner_email]})
        end
      end

      if params[:state]
        if params[:owner_email]
          filtered_tuc = filtered_tuc.where(state: params[:state])
        else
          filtered_tuc = tuc.where(state: params[:state])
        end
      end

      if params[:overdue]
        if params[:owner_email]
          filtered_tuc = filtered_tuc.where(state: 'in_progress').where("due_date < ?", Date.today).order("due_date DESC, created_at ASC")
        else
          filtered_tuc = filtered_tuc.where(state: 'in_progress').where("due_date < ?", Date.today).order("due_date DESC, created_at ASC")
        end
      elsif params[:upcoming]
        if params[:owner_email]
          filtered_tuc = filtered_tuc.where(state: 'in_progress').where("due_date >= ?", Date.today).order("due_date ASC, created_at ASC")
        else
          filtered_tuc = filtered_tuc.where(state: 'in_progress').where("due_date >= ?", Date.today).order("due_date ASC, created_at ASC")
        end
      end

      filtered_tuc
    end

    def get_owner_name(tuc)
      if tuc.jira_issue_id.present?
        'Jira'
      elsif tuc.service_now_id.present?
        'ServiceNow'
      elsif tuc.asana_id.present?
        'Asana'
      end
    end 
  end
end
