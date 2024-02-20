class DocumentsCollection < BaseCollection
  def meta
    super.tap do |h|
      h[:doc_counts] = doc_counts if params[:doc_counts].present?
    end
  end

  def total_open_documents
    relation.length
  end

  private

  def relation
    @relation ||= Document.all
  end

  def ensure_filters
    company_filter
    superuser_filter
    doc_state_filter
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
    active_employees_filter
    in_year_range_filter
    searched_user_documents_filter
  end

  def in_year_range_filter
    if params[:users_params].present? && (user_params["max_year"].present? || user_params["min_year"].present?)
      min_year = user_params["min_year"].to_i if user_params["min_year"].present?
      max_year = user_params["max_year"].to_i if user_params["max_year"].present?

      filter do |relation|
        relation
          .joins(paperwork_requests: :user)
          .where("paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)")
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
          .group("documents.id")
          .reorder('count_all desc')
          .select('documents.*, COUNT(*) AS count_all')
      end
    end
  end

  def active_employees_filter
    filter do |relation|
      relation
        .joins(paperwork_requests: :user)
        .where("(paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)) AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:registered])
        .group("documents.id")
        .reorder('count_all desc')
        .select('documents.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["active_employees"].present? && !user_params["query_year"].present?
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]) } if params[:company_id]
  end

  def superuser_filter
    filter do |relation|
      relation
        .joins(paperwork_requests: :user)
        .where("users.super_user = false")
    end if params["users_params"] && user_params["dashboard_search"].present? && user_params["sub_tab"].present? && user_params["sub_tab"] == 'dashboard'
  end

  def doc_state_filter
    filter do |relation|
      relation
        .joins(:paperwork_requests)
        .where("paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)")
        .group("documents.id")
        .reorder('count_all desc')
        .select('documents.*, COUNT(*) AS count_all')
    end  if ( params["users_params"] && user_params["state"])
  end

  def recent_employees_filter
    filter do |relation|
      relation
        .joins(paperwork_requests: :user)
        .where("(paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)) AND users.state = 'active' AND (current_stage NOT IN (:neglectStages))",
        neglectStages: [
          User.current_stages[:incomplete],
          User.current_stages[:departed],
          User.current_stages[:offboarding],
          User.current_stages[:last_week],
          User.current_stages[:last_month],
          User.current_stages[:registered]
        ]).group("documents.id")
        .reorder('count_all desc')
        .select('documents.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["recent_employees"]
  end

  def stage_filter
    filter do |relation|
      relation
        .joins(paperwork_requests: :user)
        .where("(paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)) AND users.state = 'active' AND users.current_stage IN (?)", user_params["current_stage[]"])
        .group("documents.id")
        .reorder('count_all desc')
        .select('documents.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["current_stage[]"].present?
  end

  def team_filter
    filter do |relation|
      relation
        .joins(paperwork_requests: :user)
        .where("(paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)) AND users.state = 'active' AND users.team_id IN (?)", user_params["team_id[]"])
        .group("documents.id")
        .reorder('count_all desc')
        .select('documents.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["team_id[]"].present?
  end

  def location_filter
    filter do |relation|
      relation
        .joins(paperwork_requests: :user)
        .where("(paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)) AND users.state = 'active' AND users.location_id IN (?)", user_params["location_id[]"])
        .group("documents.id")
        .reorder('count_all desc')
        .select('documents.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["location_id[]"].present?
  end

  def pre_start_filter
    filter do |relation|
      relation
        .joins(paperwork_requests: :user)
        .where("(paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)) AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:pre_start])
        .group("documents.id")
        .reorder('count_all desc')
        .select('documents.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["pre_start"]
  end

  def first_week_filter
    filter do |relation|
      relation
        .joins(paperwork_requests: :user)
        .where("(paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)) AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:first_week])
        .group("documents.id")
        .reorder('count_all desc')
        .select('documents.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["first_week"]
  end

  def first_month_filter
    filter do |relation|
      relation
        .joins(paperwork_requests: :user)
        .where("(paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)) AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:first_month])
        .group("documents.id")
        .reorder('count_all desc')
        .select('documents.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["first_month"]
  end

  def ramping_up_filter
    filter do |relation|
      relation
        .joins(paperwork_requests: :user)
        .where("(paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)) AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:ramping_up])
        .group("documents.id")
        .reorder('count_all desc')
        .select('documents.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["ramping_up"]
  end

  def user_state_filter
    filter do |relation|
      relation
        .joins(paperwork_requests: :user)
        .where("(paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)) AND users.state = 'active' AND users.current_stage IN (0, 1)")
        .group("documents.id")
        .reorder('count_all desc')
        .select('documents.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["state[]"].present?
  end

  def all_departures_filter
    filter do |relation|
      relation
        .joins(paperwork_requests: :user)
        .where("(paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)) AND users.current_stage IN (?, ?, ?, ?) AND users.termination_date > ?",
          User.current_stages[:offboarding],
          User.current_stages[:departed],
          User.current_stages[:last_month],
          User.current_stages[:last_week],
          1.month.ago
        )
        .group("documents.id")
        .reorder('count_all desc')
        .select('documents.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["all_departures"].present?
  end

  def current_stage_offboarded_filter
    filter do |relation|
      relation
        .joins(paperwork_requests: :user)
        .where("(paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)) AND users.state = 'active' AND ((users.current_stage = :offboarding_state AND users.termination_date < :current_date) OR users.current_stage = :offboarded_state) AND users.termination_date > :past_month",
                offboarding_state: 6,
                current_date:  Date.today,
                past_month: 1.month.ago,
                offboarded_state: 7
              )
        .group("documents.id")
        .reorder('count_all desc')
        .select('documents.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["current_stage_offboarded"].present?

  end

  def current_stage_offboarding_weekly_filter
    filter do |relation|
      relation
        .joins(paperwork_requests: :user)
        .where("(paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)) AND users.state = 'active' AND users.current_stage = :offboarding_state AND users.termination_date >= :currentDate AND users.termination_date < :weekDate",
                offboarding_state: 6,
                weekDate: (Date.today + 1.week),
                currentDate: Date.today
              )
        .group("documents.id")
        .reorder('count_all desc')
        .select('documents.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["current_stage_offboarding_weekly"].present?
  end

  def current_stage_offboarding_monthly_filter
    filter do |relation|
      relation
        .joins(paperwork_requests: :user)
        .where("(paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)) AND users.state = 'active' AND users.current_stage = :offboarding_state AND users.termination_date >= :weekDate AND users.termination_date < :monthDate",
                offboarding_state: 6,
                monthDate: (Date.today + 1.month),
                weekDate: (Date.today + 1.week)
              )
        .group("documents.id")
        .reorder('count_all desc')
        .select('documents.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["current_stage_offboarding_monthly"].present?
  end

  def doc_counts
    # filter { |relation| relation.joins(:paperwork_requests).count}
    relation
      .joins(:paperwork_requests)
      .where("paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NUll)" )
      .group("documents.id")
      .reorder('count_all desc')
      .count(:all)
  end

  def searched_user_documents_filter
    if  params[:users_params].present? && user_params["dashboard_search"] && user_params["term"].present?
      pattern = "#{user_params["term"].to_s.downcase}%"
      filter do |relation|
        relation
          .joins(paperwork_requests: :user)
          .where("paperwork_requests.state = 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NULL)")
          .where("lower(TRIM(first_name)) LIKE :pattern OR lower(TRIM(last_name)) LIKE :pattern OR lower(TRIM(preferred_name)) LIKE :pattern OR CONCAT(lower(TRIM(users.first_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern OR CONCAT(lower(TRIM(users.preferred_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern", pattern: pattern)
        end
    end
  end

  def user_params
    @user_params ||= JSON.parse(params["users_params"]) rescue nil
  end
end
