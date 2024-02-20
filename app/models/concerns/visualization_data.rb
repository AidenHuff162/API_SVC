module VisualizationData
  extend ActiveSupport::Concern

  def calculate_custom_date_headcounts params
    date_filter = params['date_filter']
    company_users = get_company_users(params)
    stage_filtered = company_users.where.not(current_stage: [0, 1, 2, 8, 12]).where("start_date <= ?", date_filter.to_s)
                                  .where("termination_date IS NULL OR termination_date > ?", date_filter.to_s)

    new_arrivals = []
    offboarded = []
    total_people = []

    (0..11).reverse_each do |month_index|
      month = date_filter.to_date - month_index.months
      new_date = Date.parse("#{month.year}-#{month.month}-01")
      end_of_month = month_index == 0 ? date_filter : new_date.end_of_month
      current_month_arrival_ids = company_users.where("start_date >= (?) AND start_date <= (?)", new_date.to_s, end_of_month)
                                               .where.not(current_stage: [0, 1, 2, 8, 12]).pluck(:id).uniq
      current_month_departure_ids = company_users.where("termination_date >= (?) AND termination_date <= (?)", new_date.to_s, end_of_month.to_s)
                                                 .where.not(current_stage: [0, 1, 2, 8, 12]).pluck(:id).uniq
      current_month_arrival = current_month_arrival_ids.count
      current_month_departures = current_month_departure_ids.count
      new_arrivals.push(current_month_arrival)
      offboarded.push(current_month_departures)
      if month_index == 11
        net = company_users.where.not(current_stage: [0, 1, 2, 8, 12]).where("start_date <= ?", end_of_month.to_s)
                           .where("termination_date IS NULL OR termination_date > ?", end_of_month.to_s).count
      else
        net = (total_people.last || 0)  + current_month_arrival - current_month_departures
      end

      total_people.push net
    end

    location_counts = get_location_counts(stage_filtered)
    team_counts = get_team_counts(stage_filtered)
    employment_status_counts = get_employment_status_counts(stage_filtered)

    {
      total_people: total_people,
      new_arrivals: new_arrivals,
      offboarded: offboarded,
      location_counts: location_counts,
      team_counts: team_counts,
      employment_status_counts: employment_status_counts
    }
  end

  private

  def get_company_users(params)
    filters = JSON.parse(params['filters'])
    team_ids = []
    location_ids = []
    if filters.present?
      filters['Departments'].try(:each) do |k,v|
        team_ids.push v
      end
      filters['Locations'].try(:each) do |k,v|
        location_ids.push v
      end
    end

    company_users = self.users.where(super_user: false)
    company_users = company_users.where(location_id: location_ids) unless location_ids.first.blank?
    company_users = company_users.where(team_id: team_ids) unless team_ids.first.blank?

    if filters.present?
      company_users = company_users.includes(:custom_field_values)
      option_users_ids = company_users.ids
      filters['mcq'].try(:each) do |k, v|
        unless v&.first.blank?
          mcq_users_ids = company_users.where(custom_field_values: { custom_field_option_id: v }).ids
          option_users_ids = option_users_ids & mcq_users_ids
        end
      end
      if filters['employment_status'].present?
        employment_status_field = self.custom_fields.includes(:custom_table).find_by(name: 'Employment Status')
        filters['employment_status'].try(:each) do |k, v|
          unless v&.first.blank?
            status_users_ids =  if employment_status_field&.custom_table_id.present?
                                  company_users.joins(custom_table_user_snapshots: :custom_snapshots).where(custom_table_user_snapshots: {custom_table_id: employment_status_field.custom_table_id, state: 1}, custom_snapshots: {custom_field_id: employment_status_field.id}).where(custom_snapshots: { custom_field_value: v }).ids
                                else
                                  company_users.where(custom_field_values: { custom_field_option_id: v }).ids
                                end
            option_users_ids = option_users_ids & status_users_ids
          end
        end
      end
      company_users = company_users.where(id: option_users_ids)
    end

    company_users
  end

  def get_location_counts stage_filtered
    location_counts = stage_filtered.group('locations.name').order('COUNT(users.id) DESC').joins('LEFT OUTER JOIN locations ON users.location_id = locations.id AND locations.active = true').count
  end

  def get_team_counts stage_filtered
    team_counts = stage_filtered.group('teams.name').order('COUNT(users.id) DESC').joins('LEFT OUTER JOIN teams ON users.team_id = teams.id AND teams.active = true').count
  end

  def get_employment_status_counts stage_filtered
    employment_status_counts = {}
    status_count = {}

    employment_status_field = self.custom_fields.includes(:custom_table).find_by(name: "Employment Status")
    unless employment_status_field.nil?
      if employment_status_field.custom_table_id
        status_count = stage_filtered.joins(custom_table_user_snapshots: :custom_snapshots).where(custom_table_user_snapshots: {custom_table_id: employment_status_field.custom_table_id, state: 1}, custom_snapshots: {custom_field_id: employment_status_field.id}).group('custom_snapshots.custom_field_value').order('COUNT(users.id) DESC').count
      else
        status_count = stage_filtered.joins(:custom_field_values => [custom_field_option: :custom_field]).where("custom_fields.field_type = 13").group('custom_field_values.custom_field_option_id').order('COUNT(users.id) DESC').count
      end
      status_count.each do |key, value|
        status_name = employment_status_field.custom_field_options.find(key).option rescue "invalid"
        employment_status_counts[status_name] = value
      end
    end
    employment_status_counts
  end

end
