class AdminGroupTypesCollection
  attr_reader :params

  def initialize(params)
    @params = params
  end

  def results
    @results ||= begin
      get_requests
    end
  end

  def count
    if params[:group_name] == "Locations"
      ApplicationRecord.connection.exec_query("
        SELECT COUNT(*)
        FROM locations WHERE deleted_at IS NULL #{location_term_filter} AND company_id = #{params[:company_id]}
      ").first['count'].to_i
    elsif params[:group_name] == "Departments"
      ApplicationRecord.connection.exec_query("
        SELECT COUNT(*)
        FROM teams WHERE company_id = #{params[:company_id]} #{team_term_filter}
      ").first['count'].to_i
    end
  end

  private

  def get_requests
    if params[:group_name] == "Locations"
      @relation = ApplicationRecord.connection.exec_query("
        SELECT *
        FROM locations WHERE deleted_at IS NULL #{location_term_filter} AND company_id = #{params[:company_id]}
        ORDER BY  #{order_by}
        OFFSET #{(params[:page] - 1) * params[:per_page].to_i}
        LIMIT #{params[:per_page]}
      ")
    elsif params[:group_name] == "Departments"
      @relation = ApplicationRecord.connection.exec_query("
        SELECT *
        FROM teams WHERE company_id = #{params[:company_id]} #{team_term_filter}
        ORDER BY  #{order_by}
        OFFSET #{(params[:page] - 1) * params[:per_page].to_i}
        LIMIT #{params[:per_page]}
      ")
    end
  end

  def location_term_filter
    return unless params[:term]
    data = params[:term] if params[:term]
    " AND name ILIKE '%#{data}%' " if data.present?
  end

  def team_term_filter
    return unless params[:term]
    data = params[:term] if params[:term]
    "AND name ILIKE '%#{data}%' " if data.present?
  end

  def order_by
    order = ""
    order = params[:sort_column]
    order += " " +params[:sort_order]
    order
  end

end