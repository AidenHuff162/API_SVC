class CustomTableUserSnapshotsDashboardCollection
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
    ApplicationRecord.connection.exec_query("
      #{collective_filter}
      SELECT COUNT(*)
      FROM approval_requests
    ").first['count'].to_i
  end

  private

  def term_query(tab)
    if params[:term].present?
      "AND (#{tab}.name ilike '%#{params[:term]}%')"
    else
      ""
    end
  end

  def collective_filter
    "
      WITH approval_requests AS (
        #{dash_filter}
      )
    "
  end

  def get_requests
    @relation = ApplicationRecord.connection.exec_query("
      #{collective_filter}
      SELECT *
      FROM approval_requests
      ORDER BY  #{params[:sort_column]} #{params[:sort_order]}
      OFFSET #{(params[:page] - 1) * params[:per_page].to_i}
      LIMIT #{params[:per_page]}
    ")
  end

  def dash_filter
    request_condition = if params[:requested].present?
                          " ctus.request_state = #{CustomTableUserSnapshot.request_states[:requested]} "
                        else
                          " (ctus.request_state = #{CustomTableUserSnapshot.request_states[:denied]} or ctus.request_state = #{CustomTableUserSnapshot.request_states[:approved]}) "
                        end

    "SELECT DISTINCT ctus.id, ctus.effective_date as effect_date, ctus.user_id, ctus.created_at as request_date, 
    tble.name as custom_table_name, u.preferred_name,  
    sum(tble.approval_expiry_time - DATE_PART('day', now()::timestamp - ctus.created_at::timestamp)) as expire_time,
    ctus.request_state as status, ctus.updated_at

    FROM custom_table_user_snapshots as ctus 
    INNER JOIN custom_tables as tble 
    ON ctus.custom_table_id = tble.id AND tble.is_approval_required = TRUE 
    
    INNER JOIN users as u ON u.id = ctus.user_id AND u.deleted_at IS NULL 
    
    WHERE tble.company_id = #{params[:company_id]} 
    AND #{request_condition} 
    AND tble.deleted_at IS NULL AND ctus.deleted_at IS NULL " + term_query('tble') + " GROUP By ctus.id, tble.name, u.preferred_name "
  end
end