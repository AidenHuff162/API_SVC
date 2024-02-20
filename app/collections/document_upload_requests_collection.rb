class DocumentUploadRequestsCollection < BaseCollection

  def meta
    super.tap do |h|
      h[:doc_counts] = doc_counts if params[:doc_counts].present?
    end
  end

  def total_open_uploads
    relation.length
  end

  private

  def relation
    @relation ||= DocumentUploadRequest.all
  end

  def ensure_filters
    company_filter
    meta_filter
    global_filter
    title_filter
    onboarding_plan_filter
    sorting_filter
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
    exclude_by_id_filter
    include_ids_filter
    active_employees_filter
    in_year_range_filter
    employee_type_filter
    team_filter
    location_filter
    custom_group_filter
    type_filter
  end

  def in_year_range_filter
    if params[:users_params].present? && JSON.parse(params["users_params"])["query_year"].present?
      year = JSON.parse(params["users_params"])["query_year"].to_i

      if params["users_params"] && JSON.parse(params["users_params"])["retention"].present?
        filter do |relation|
          relation
            .joins(document_connection_relation: :user_document_connections)
            .joins("INNER JOIN users ON users.id = user_document_connections.user_id")
            .where(user_document_connections: {state: 'request'})
            .where("users.start_date < ? AND users.current_stage = ?", year.years.ago.to_date, User.current_stages[:registered])
            .group("document_upload_requests.id")
            .reorder('count_all desc')
            .select('document_upload_requests.*, COUNT(*) AS count_all')
        end
      else
        filter do |relation|
          relation
            .joins(document_connection_relation: :user_document_connections)
            .joins("INNER JOIN users ON users.id = user_document_connections.user_id")
            .where(user_document_connections: {state: 'request'})
            .where("users.start_date BETWEEN ? AND ? AND users.current_stage = ?", year.years.ago.to_date + 1.day, (year - 1).years.ago.to_date, User.current_stages[:registered])
            .group("document_upload_requests.id")
            .reorder('count_all desc')
            .select('document_upload_requests.*, COUNT(*) AS count_all')
        end
      end
    end
  end

  def active_employees_filter
    filter do |relation|
      relation
        .joins(document_connection_relation: :user_document_connections)
        .joins("INNER JOIN users ON users.id = user_document_connections.user_id")
        .where("user_document_connections.state = 'request' AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:registered])
        .group("document_upload_requests.id")
        .reorder('count_all desc')
        .select('document_upload_requests.*, COUNT(*) AS count_all')
    end if params["users_params"] && JSON.parse(params["users_params"])["active_employees"].present? && !JSON.parse(params["users_params"])["query_year"].present?
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]) } if params[:company_id]
  end

  def exclude_by_id_filter
    filter do |relation|
      user_relation = relation.joins(:document_connection_relation).joins("LEFT JOIN user_document_connections ON user_document_connections.document_connection_relation_id = document_connection_relations.id AND user_document_connections.deleted_at IS NULL").where("user_document_connections.user_id = ?", params[:exclude_by_id])
      relation = relation - user_relation
    end if params[:exclude_by_id]
  end

  def global_filter
    filter { |relation| relation.where(global: params[:global]) } if params[:global]
  end

  def title_filter
    filter do |relation|
      pattern = "%#{params[:term].to_s.downcase}%"

      title_query = 'concat_ws(\' \', lower(title)) LIKE ?'

      relation.joins(:document_connection_relation).where("#{title_query}", pattern)
    end if params[:term]
  end

  def sorting_filter
    if params[:order_column] && params[:order_in]
      order_in = params[:order_in].downcase == 'asc' ? 'asc' : 'desc'
      if params[:order_column] == 'title'
        filter do |relation|
          relation
            .joins(:document_connection_relation)
            .reorder("#{params[:order_column]} #{order_in}")
        end
      elsif params[:order_column] == 'type'
        filter do |relation|
          relation
            .reorder("meta -> 'type' #{order_in}")
        end
      end
    end
  end

  def state_filter
    filter do |relation|
      relation
        .joins(document_connection_relation: :user_document_connections)
        .where("user_document_connections.state= 'request'")
        .group("document_upload_requests.id")
        .reorder('count_all desc')
        .select('document_upload_requests.*, COUNT(*) AS count_all')
    end  if ( params["users_params"] && JSON.parse(params["users_params"])["state"])
  end

  def pre_start_filter
    filter do |relation|
      relation
        .joins(document_connection_relation: :user_document_connections)
        .joins("INNER JOIN users ON users.id = user_document_connections.user_id")
        .where("(user_document_connections.state= 'request') AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:pre_start])
        .group("document_upload_requests.id")
        .reorder('count_all desc')
        .select('document_upload_requests.*, COUNT(*) AS count_all')
    end if params["users_params"] && JSON.parse(params["users_params"])["pre_start"]
  end

  def first_week_filter
    filter do |relation|
      relation
        .joins(document_connection_relation: :user_document_connections)
        .joins("INNER JOIN users ON users.id = user_document_connections.user_id")
        .where("(user_document_connections.state= 'request') AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:first_week])
        .group("document_upload_requests.id")
        .reorder('count_all desc')
        .select('document_upload_requests.*, COUNT(*) AS count_all')
    end if params["users_params"] && JSON.parse(params["users_params"])["first_week"]
  end

  def first_month_filter
    filter do |relation|
      relation
        .joins(document_connection_relation: :user_document_connections)
        .joins("INNER JOIN users ON users.id = user_document_connections.user_id")
        .where("(user_document_connections.state= 'request') AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:first_month])
        .group("document_upload_requests.id")
        .reorder('count_all desc')
        .select('document_upload_requests.*, COUNT(*) AS count_all')
    end if params["users_params"] && JSON.parse(params["users_params"])["first_month"]
  end

  def ramping_up_filter
    filter do |relation|
      relation
        .joins(document_connection_relation: :user_document_connections)
        .joins("INNER JOIN users ON users.id = user_document_connections.user_id")
        .where("(user_document_connections.state= 'request') AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:ramping_up])
        .group("document_upload_requests.id")
        .reorder('count_all desc')
        .select('document_upload_requests.*, COUNT(*) AS count_all')
    end if params["users_params"] && JSON.parse(params["users_params"])["ramping_up"]
  end

  def user_state_filter
    filter do |relation|
      relation
        .joins(document_connection_relation: :user_document_connections)
        .joins("INNER JOIN users ON users.id = user_document_connections.user_id")
        .where("(user_document_connections.state= 'request') AND user.state = 'active' AND users.current_stage IN (?, ?)", User.current_stages[:invited], User.current_stages[:preboarding])
        .group("document_upload_requests.id")
        .reorder('count_all desc')
        .select('document_upload_requests.*, COUNT(*) AS count_all')
    end if params["users_params"] && JSON.parse(params["users_params"])["state[]"].present?
  end

  def all_departures_filter
    filter do |relation|
      relation
        .joins(document_connection_relation: :user_document_connections)
        .joins("INNER JOIN users ON users.id = user_document_connections.user_id")
        .where("(user_document_connections.state= 'request') AND users.current_stage IN (?, ?, ?, ?)",
          User.current_stages[:offboarding],
          User.current_stages[:departed],
          User.current_stages[:last_month],
          User.current_stages[:last_week]
        )
        .group("document_upload_requests.id")
        .reorder('count_all desc')
        .select('document_upload_requests.*, COUNT(*) AS count_all')
    end if params["users_params"] && JSON.parse(params["users_params"])["all_departures"].present?
  end

  def current_stage_offboarded_filter
    filter do |relation|
      relation
        .joins(document_connection_relation: :user_document_connections)
        .joins("INNER JOIN users ON users.id = user_document_connections.user_id")
        .where("(user_document_connections.state= 'request') AND users.current_stage = ?", User.current_stages[:departed])
        .group("document_upload_requests.id")
        .reorder('count_all desc')
        .select('document_upload_requests.*, COUNT(*) AS count_all')
    end if params["users_params"] && JSON.parse(params["users_params"])["current_stage_offboarded"].present?

  end

  def current_stage_offboarding_weekly_filter
    filter do |relation|
      relation
        .joins(document_connection_relation: :user_document_connections)
        .joins("INNER JOIN users ON users.id = user_document_connections.user_id")
        .where("(user_document_connections.state= 'request') AND users.state = 'active' AND users.current_stage = ? ", User.current_stages[:last_week])
        .group("document_upload_requests.id")
        .reorder('count_all desc')
        .select('document_upload_requests.*, COUNT(*) AS count_all')
    end if params["users_params"] && JSON.parse(params["users_params"])["current_stage_offboarding_weekly"].present?
  end

  def current_stage_offboarding_monthly_filter
    filter do |relation|
      relation
        .joins(document_connection_relation: :user_document_connections)
        .joins("INNER JOIN users ON users.id = user_document_connections.user_id")
        .where("(user_document_connections.state= 'request') AND users.state = 'active' AND users.current_stage = ? ", User.current_stages[:last_month])
        .group("document_upload_requests.id")
        .reorder('count_all desc')
        .select('document_upload_requests.*, COUNT(*) AS count_all')
    end if params["users_params"] && JSON.parse(params["users_params"])["current_stage_offboarding_monthly"].present?
  end

  def doc_counts
    relation
      .joins(document_connection_relation: :user_document_connections)
      .where("user_document_connections.state= 'request'")
      .group("document_upload_requests.id")
      .reorder('count_all desc')
      .count(:all)
  end

  def include_ids_filter
    filter do |relation|
      relation.where("id IN (?)", params[:include_ids])
    end if params[:include_ids]
  end

  def employee_type_filter
    if params["employment_status_option"]
      filter { |relation| relation.where("meta -> 'employee_type'  @> ? OR meta -> 'employee_type' @> ?", ['all'].to_s, params["employment_status_option"].to_s) }
    end
  end

  def team_filter
    if params["team_id"]
      filter { |relation| relation.where("meta -> 'team_id'  @> ? OR meta -> 'team_id' @> ?", ['all'].to_s, params["team_id"].map{|p| p.to_i}.to_s) }
    end
  end

  def location_filter
    if params["location_id"]
      filter { |relation| relation.where("meta -> 'location_id'  @> ? OR meta -> 'location_id' @> ?",['all'].to_s, params["location_id"].map{|p| p.to_i}.to_s) }
    end
  end

  def custom_group_filter
    if params["custom_field_option_id"]
      custom_groups = {}
      params["custom_field_option_id"].each do |p|
        key = p.split('-')[0].to_s
        value = p.split('-')[1].to_i
        custom_groups[key] ||= []
         custom_groups[key].push(value)
      end
      custom_groups.each do |key, value|
        filter { |relation| relation.where("meta -> '#{key}'  @> ? OR meta -> '#{key}' @> ?", ['all'].to_s, custom_groups["#{key}"].to_s) }
      end
    end
  end

  def type_filter
    if params["template_type"]
      filter { |relation| relation.where("meta -> 'type'  <@ ?", params["template_type"].to_s) }
    end
  end

  def onboarding_plan_filter
    filter { |relation| relation.where("meta -> 'type'  <@ ?", ['Onboarding', 'Offboarding'].to_s) } if params[:onboarding_plan]
  end

  def meta_filter
    filter { |relation| relation.where("meta::text != '{}'") }
  end
end
