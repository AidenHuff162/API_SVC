class DocumentConnectionRelationsCollection < BaseCollection

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
    @relation ||= DocumentConnectionRelation.all
  end

  def ensure_filters
    company_filter
    superuser_filter
    global_filter
    title_filter
    sorting_filter
    state_filter
    recent_employees_filter
    stage_filter
    team_filter
    location_filter
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

    active_employees_filter
    in_year_range_filter
    searched_user_document_upload_requests_filter
  end

  def in_year_range_filter
    if params[:users_params].present? && (user_params["max_year"].present? || user_params["min_year"].present?)
      min_year = user_params["min_year"].to_i if user_params["min_year"].present?
      max_year = user_params["max_year"].to_i if user_params["max_year"].present?

      filter do |relation|
        relation
          .joins(user_document_connections: :user)
          .where(user_document_connections: {state: 'request'})
      end
      #individual cases
      filter {|relation| relation.where("users.start_date > ?", min_year.years.ago.to_date)} if !user_params["max_year"].present? && !user_params["combined_query"].present? && !user_params["retention"].present?#11
      filter {|relation| relation.where("users.start_date BETWEEN ? AND ?", max_year.years.ago.to_date + 1.day, (max_year - 1).years.ago.to_date)} if !user_params["min_year"].present? && !user_params["combined_query"].present? && !user_params["retention"].present? #12
      filter {|relation| relation.where("users.start_date < ?", max_year.years.ago.to_date + 1.day)} if !user_params["combined_query"].present? && user_params["retention"].present? #13

      #combined cases
      filter {|relation| relation.where("users.start_date > ?", max_year.years.ago.to_date)} if user_params["combined_query"].present? && !user_params["retention"].present? #11, 12
      filter {|relation| relation.where("(users.start_date BETWEEN ? AND ?) OR (users.start_date < ?)", min_year.years.ago.to_date + 1.day, (min_year - 1).years.ago.to_date, max_year.years.ago.to_date)} if user_params["combined_query"].present? && user_params["retention"].present? && user_params["min_year"].present? #11, 13
      filter {|relation| relation.where("users.start_date < ?", (max_year - 1).years.ago.to_date)} if user_params["combined_query"].present? && user_params["retention"].present? && !user_params["min_year"].present? #12, 13

      filter do |relation|
        relation
          .group("document_connection_relations.id")
          .reorder('count_all desc')
          .select('document_connection_relations.*, COUNT(*) AS count_all')
      end
    end
  end

  def active_employees_filter
    filter do |relation|
      relation
        .joins(user_document_connections: :user)
        .where("user_document_connections.state = 'request' AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:registered])
        .group("document_connection_relations.id")
        .reorder('count_all desc')
        .select('document_connection_relations.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["active_employees"].present? && !user_params["query_year"].present?
  end

  def recent_employees_filter
    filter do |relation|
      relation
        .joins(user_document_connections: :user)
        .where("user_document_connections.state = 'request' AND users.state = 'active' AND users.current_stage NOT IN (:neglectStages)",
        neglectStages: [
          User.current_stages[:incomplete],
          User.current_stages[:departed],
          User.current_stages[:offboarding],
          User.current_stages[:last_week],
          User.current_stages[:last_month],
          User.current_stages[:registered]
        ]).group("document_connection_relations.id")
        .reorder('count_all desc')
        .select('document_connection_relations.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["recent_employees"].present?
  end

  def company_filter
    filter { |relation| relation.joins(:user_document_connections).where(user_document_connections: {company_id: params[:company_id]}) } if params[:company_id]
  end

  def superuser_filter
    filter do |relation|
      relation
        .joins(user_document_connections: :user)
        .where("users.super_user = false")
    end if params["users_params"] && user_params["dashboard_search"].present? && user_params["sub_tab"].present? && user_params["sub_tab"] == 'dashboard'
  end

  def exclude_by_id_filter
    filter do |relation|
      relation
        .joins("LEFT JOIN user_document_connections ON user_document_connections.document_upload_request_id = document_upload_requests.id AND user_document_connections.user_id = #{params[:exclude_by_id]} AND user_document_connections.deleted_at IS NULL")
        .where("user_document_connections.id IS NULL")
    end if params[:exclude_by_id]
  end

  def global_filter
    filter { |relation| relation.joins(:user_document_connections).where(user_document_connections: {global: params[:global]}) } if params[:global]
  end

  def title_filter
    filter do |relation|
      pattern = "%#{params[:term].to_s.downcase}%"

      title_query = 'concat_ws(\' \', lower(title)) LIKE ?'

      relation.where("#{title_query}", pattern)
    end if params[:term]
  end

  def sorting_filter
    if params[:order_column] && params[:order_in]
      if params[:order_column] == 'title' || params[:order_column] == 'description'
        order_in = params[:order_in].downcase == 'asc' ? 'asc' : 'desc'
        filter do |relation|
          relation
            .reorder("#{params[:order_column]} #{order_in}")
        end
      end
    end
  end

  def state_filter
    filter do |relation|
      relation
        .joins(:user_document_connections)
        .where("user_document_connections.state= 'request'")
        .group("document_connection_relations.id")
        .reorder('count_all desc')
        .select('document_connection_relations.*, COUNT(*) AS count_all')
    end  if ( params["users_params"] && user_params["state"])
  end

  def pre_start_filter
    filter do |relation|
      relation
        .joins(user_document_connections: :user)
        .where("(user_document_connections.state= 'request') AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:pre_start])
        .group("document_connection_relations.id")
        .reorder('count_all desc')
        .select('document_connection_relations.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["pre_start"]
  end

  def stage_filter
    filter do |relation|
      relation
        .joins(user_document_connections: :user)
        .where("(user_document_connections.state= 'request') AND users.state = 'active' AND users.current_stage IN (?)", user_params["current_stage[]"])
        .group("document_connection_relations.id")
        .reorder('count_all desc')
        .select('document_connection_relations.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["current_stage[]"].present?
  end

  def team_filter
    filter do |relation|
      relation
        .joins(user_document_connections: :user)
        .where("(user_document_connections.state= 'request') AND users.state = 'active' AND users.team_id IN (?)", user_params["team_id[]"])
        .group("document_connection_relations.id")
        .reorder('count_all desc')
        .select('document_connection_relations.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["team_id[]"].present?
  end

  def location_filter
    filter do |relation|
      relation
        .joins(user_document_connections: :user)
        .where("(user_document_connections.state= 'request') AND users.state = 'active' AND users.location_id IN (?)", user_params["location_id[]"])
        .group("document_connection_relations.id")
        .reorder('count_all desc')
        .select('document_connection_relations.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["location_id[]"].present?
  end

  def first_week_filter
    filter do |relation|
      relation
        .joins(user_document_connections: :user)
        .where("(user_document_connections.state= 'request') AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:first_week])
        .group("document_connection_relations.id")
        .reorder('count_all desc')
        .select('document_connection_relations.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["first_week"]
  end

  def first_month_filter
    filter do |relation|
      relation
        .joins(user_document_connections: :user)
        .where("(user_document_connections.state= 'request') AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:first_month])
        .group("document_connection_relations.id")
        .reorder('count_all desc')
        .select('document_connection_relations.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["first_month"]
  end

  def ramping_up_filter
    filter do |relation|
      relation
        .joins(user_document_connections: :user)
        .where("(user_document_connections.state= 'request') AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:ramping_up])
        .group("document_connection_relations.id")
        .reorder('count_all desc')
        .select('document_connection_relations.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["ramping_up"]
  end

  def user_state_filter
    filter do |relation|
      relation
        .joins(user_document_connections: :user)
        .where("(user_document_connections.state= 'request') AND user.state = 'active' AND users.current_stage IN (?, ?)", User.current_stages[:invited], User.current_stages[:preboarding])
        .group("document_connection_relations.id")
        .reorder('count_all desc')
        .select('document_connection_relations.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["state[]"].present?
  end

  def all_departures_filter
    filter do |relation|
      relation
        .joins(user_document_connections: :user)
        .where("(user_document_connections.state= 'request') AND users.current_stage IN (?, ?, ?, ?)",
          User.current_stages[:offboarding],
          User.current_stages[:departed],
          User.current_stages[:last_month],
          User.current_stages[:last_week]
        )
        .group("document_connection_relations.id")
        .reorder('count_all desc')
        .select('document_connection_relations.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["all_departures"].present?
  end

  def current_stage_offboarded_filter
    filter do |relation|
      relation
        .joins(user_document_connections: :user)
        .where("(user_document_connections.state= 'request') AND users.current_stage = ?", User.current_stages[:departed])
        .group("document_connection_relations.id")
        .reorder('count_all desc')
        .select('document_connection_relations.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["current_stage_offboarded"].present?

  end

  def current_stage_offboarding_weekly_filter
    filter do |relation|
      relation
        .joins(user_document_connections: :user)
        .where("(user_document_connections.state= 'request') AND users.state = 'active' AND users.current_stage = ? ", User.current_stages[:last_week])
        .group("document_connection_relations.id")
        .reorder('count_all desc')
        .select('document_connection_relations.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["current_stage_offboarding_weekly"].present?
  end

  def current_stage_offboarding_monthly_filter
    filter do |relation|
      relation
        .joins(user_document_connections: :user)
        .where("(user_document_connections.state= 'request') AND users.state = 'active' AND users.current_stage = ? ", User.current_stages[:last_month])
        .group("document_connection_relations.id")
        .reorder('count_all desc')
        .select('document_connection_relations.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["current_stage_offboarding_monthly"].present?
  end

  def doc_counts
    relation
      .joins(:user_document_connections)
      .where("user_document_connections.state= 'request' AND user_document_connections.user_id IS NOT NULL")
      .group("document_connection_relations.id")
      .reorder('count_all desc')
      .count(:all)
  end

  def searched_user_document_upload_requests_filter
    if  params[:users_params].present? && user_params["dashboard_search"] && user_params["term"].present?
      pattern = "#{user_params["term"].to_s.downcase}%"
      filter do |relation|
        relation
          .joins(user_document_connections: :user)
          .where(user_document_connections: {state: 'request'})
          .where("lower(TRIM(first_name)) LIKE :pattern OR lower(TRIM(last_name)) LIKE :pattern OR lower(TRIM(preferred_name)) LIKE :pattern OR CONCAT(lower(TRIM(users.first_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern OR CONCAT(lower(TRIM(users.preferred_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern", pattern: pattern)
        end
    end
  end

  def user_params
    @user_params ||= JSON.parse(params["users_params"]) rescue nil
  end
end
