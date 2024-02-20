class PaperworkRequestsCollection < BaseCollection
  def meta
    super.tap do |h|
      h[:doc_counts] = doc_counts if params[:doc_counts].present?
    end
  end

  private

  def relation
    @relation ||= PaperworkRequest.all
  end

  def ensure_filters
    company_filter
    user_current_stage_filter
    user_filter
    onboard_filter
    state_filter
    pre_start_filter
    first_week_filter
    first_month_filter
    ramping_up_filter
    user_state_filter
    all_departures_filter
    current_stage_offboarded_filter
    current_stage_offboarding_weekly_filter
    current_stage_offboarding_monthly_filter
    activity_id_filter
    sorting_filter
    team_filter
    location_filter
    employee_type_filter
    status_filter
    exclude_drafts_filter
    multiple_custom_groups_filter
    multiple_custom_groups_employee_type_filter
  end

  def company_filter
    filter { |relation| relation.joins(:document).where(documents: {company_id: params[:company_id]}) } if params[:company_id]
  end

  def onboard_filter
    onboard_states = ['assigned', 'emp_submitted', 'signed', 'cosigner_submitted', 'all_signed']
    filter { |relation| relation.where(state: onboard_states) } if params[:onboard]
  end

  def user_filter
    filter { |relation| relation.where("(paperwork_requests.co_signer_id = :userId AND paperwork_requests.state = 'signed') OR paperwork_requests.user_id = :userId", userId: params[:user_id])} if params[:user_id]
  end

  def state_filter
    filter { |relation| relation.where("paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)") } if params[:state]
  end

  def pre_start_filter
    filter do |relation|
      relation
        .joins(:user)
        .where("users.state = 'active' AND users.current_stage = ?", User.current_stages[:pre_start])
    end if params["users_params"] && JSON.parse(params["users_params"])["pre_start"]
  end

  def first_week_filter
    filter do |relation|
      relation
        .joins(:user)
        .where("users.state = 'active' AND users.current_stage = ?", User.current_stages[:first_week])
    end if params["users_params"] && JSON.parse(params["users_params"])["first_week"]
  end

  def first_month_filter
    filter do |relation|
      relation
        .joins(:user)
        .where("users.state = 'active' AND users.current_stage = ?", User.current_stages[:first_month])
    end if params["users_params"] && JSON.parse(params["users_params"])["first_month"]
  end

  def ramping_up_filter
    filter do |relation|
      relation
        .joins(:user)
        .where("users.state = 'active' AND users.current_stage = ?", User.current_stages[:ramping_up])
    end if params["users_params"] && JSON.parse(params["users_params"])["ramping_up"]
  end

  def user_state_filter
    filter do |relation|
      relation
        .joins(:user)
        .where("user.state = 'active' AND users.current_stage IN (?, ?)", User.current_stages[:invited], User.current_stages[:preboarding])
    end if params["users_params"] && JSON.parse(params["users_params"])["state[]"].present?
  end

  def all_departures_filter
    filter do |relation|
      relation
        .joins(:user)
        .where("users.current_stage IN (?, ?, ?, ?)",
          User.current_stages[:offboarding],
          User.current_stages[:departed],
          User.current_stages[:last_month],
          User.current_stages[:last_week]
        )
    end if params["users_params"] && JSON.parse(params["users_params"])["all_departures"].present?
  end

  def current_stage_offboarded_filter
    filter do |relation|
      relation
        .joins(:user)
        .where("users.current_stage = ?", User.current_stages[:departed])
    end if params["users_params"] && JSON.parse(params["users_params"])["current_stage_offboarded"].present?

  end

  def current_stage_offboarding_weekly_filter
    filter do |relation|
      relation
        .joins(:user)
        .where("users.state = 'active' AND users.current_stage = ? ", User.current_stages[:last_week])
    end if params["users_params"] && JSON.parse(params["users_params"])["current_stage_offboarding_weekly"].present?
  end

  def current_stage_offboarding_monthly_filter
    filter do |relation|
      relation
        .joins(:user)
        .where("users.state = 'active' AND users.current_stage = ? ", User.current_stages[:last_month])
    end if params["users_params"] && JSON.parse(params["users_params"])["current_stage_offboarding_monthly"].present?
  end


  def doc_counts
    Document
      .joins(:paperwork_requests)
      .where(" paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NUll)" )
      .group("documents.id")
      .count
  end

  def activity_id_filter
    filter do |relation|
      relation.where("(paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NUll)) AND paperwork_requests.document_id=?", params[:activity_id] )
    end if params[:activity_id]
  end

  def sorting_filter
    if params[:order_column] && params[:order_in]
      order_in = params[:order_in].downcase == 'asc' ? 'asc' : 'desc'

      if params[:order_column] == 'doc_name'
        filter { |relation| relation.joins(:document).order("LOWER(documents.title) #{order_in}") }

      elsif params[:order_column] == 'due_date'
        filter { |relation| relation.reorder("paperwork_requests.created_at #{order_in}, paperwork_requests.id asc") }
      end
    end
  end

  def team_filter
    filter do |relation|
      relation.joins(:user).where(users: {team_id: params[:team_id]})
    end if params[:team_id]
  end

  def location_filter
    filter do |relation|
      relation.joins(:user).where(users: {location_id: params[:location_id]})
    end if params[:location_id]
  end

  def employee_type_filter
    if params[:company_id] && params[:employee_type] && params[:employee_type] != 'All Employee Status' && !params[:multiple_custom_groups]
      filter { |relation| relation.joins(:user => {:custom_field_values => [custom_field_option: :custom_field]}).where("custom_fields.company_id = ? AND custom_fields.field_type = ? AND custom_field_options.option IN (?)", params[:company_id], 13, params[:employee_type]) }
    end
  end

  def status_filter
    if params[:status] && params[:status] == 'completed_docs'
      filter { |relation| relation.where("(paperwork_requests.co_signer_id IS NULL AND paperwork_requests.state = 'signed') OR (paperwork_requests.co_signer_id IS NOT NULL AND paperwork_requests.state = 'all_signed')")}
    elsif params[:status] && params[:status] == 'in_progress_docs'
      filter { |relation| relation.where("(paperwork_requests.co_signer_id IS NULL AND paperwork_requests.state <> 'signed') OR (paperwork_requests.co_signer_id IS NOT NULL AND paperwork_requests.state <> 'all_signed')")}
    end
  end

  def exclude_drafts_filter
    filter { |relation| relation.where.not(state: 'draft') } if params[:exclude_drafts]
  end

  def multiple_custom_groups_filter
    if params[:multiple_custom_groups] && params[:multiple_custom_groups].length > 0 && !params[:employee_type]
      a = filter { |relation| relation.joins(user: :custom_field_values)  }
      string1 = ""
      a = filter { |relation| relation.joins(user: :custom_field_values)  }
      params[:multiple_custom_groups].each do |filter|
        string1 = "(custom_field_values.custom_field_id = #{filter[:custom_field_id]} AND custom_field_values.custom_field_option_id IN (#{filter[:custom_field_option_id].reject(&:blank?).join(',')}))"
        a = a  & relation.where(string1)
      end
      filter { |relation| relation  & a}
    end
  end

  def multiple_custom_groups_employee_type_filter
    if params[:multiple_custom_groups] && params[:multiple_custom_groups].length > 0 && params[:employee_type]
      filter { |relation| relation.joins(:user => {:custom_field_values => [custom_field_option: :custom_field]}) }
      string1 = ""
      string2 = ""
      a = filter { |relation| relation.joins(:user => {:custom_field_values => [custom_field_option: :custom_field]}) }
      params[:multiple_custom_groups].each do |filter|
        string1 = "(custom_field_values.custom_field_id = #{filter[:custom_field_id]} AND custom_field_values.custom_field_option_id IN (#{filter[:custom_field_option_id].reject(&:blank?).join(',')}))"
        a = a  & relation.where(string1)
      end
      string2 = "custom_fields.company_id = #{params[:company_id]} AND custom_fields.field_type = 13 AND custom_field_options.option IN (?)"
      filter { |relation| a  & relation.where(string2,params[:employee_type])}
    end
  end

  def user_current_stage_filter
    if params[:user_state_filter] && !params[:user_state_filter].eql?('all_users')
      current_stages =  case params[:user_state_filter]
                        when 'onboarding_only'
                          [ User.current_stages[:invited], 
                            User.current_stages[:preboarding], 
                            User.current_stages[:pre_start], 
                            User.current_stages[:first_week], 
                            User.current_stages[:first_month], 
                            User.current_stages[:ramping_up] ]
                        when 'active_only'
                          [ User.current_stages[:registered] ]
                        when 'offboarding_only'
                          [ User.current_stages[:offboarding],
                            User.current_stages[:last_month],
                            User.current_stages[:last_week] ]
                        when 'departed_only'
                          [ User.current_stages[:departed] ]
                        end
      filter { |relation| relation.joins(:user).where(users: { current_stage: current_stages })}
    end
  end
end
