class CustomSectionApprovalsDashboardCollection
  attr_reader :params

  def initialize(params)
    @params = params
  end

  def results
    @results ||= begin
      get_requests if params[:process_type] && params[:process_type] == "Profile Information"
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

  def sorting_filter
    sorting = ""
    if params[:sort_column]
      if params[:sort_column] == "custom_table_name"
        if params[:process_type] == "Profile Information"
          sorting = "custom_section_name"
        else params[:process_type] == "Job Details"
          sorting = "custom_table_name"
        end
      else
        sorting = params[:sort_column]
      end
    end
    sorting += " " + params[:sort_order] if params[:sort_order]
    sorting
  end

  def term_filter
    return unless params[:term]
    data = params[:term] if params[:term]
    " AND (case cs.section
      when 0 then '#{CustomSection.sections.key(0)}'
      when 1 then '#{CustomSection.sections.key(1)}'
      when 2 then '#{CustomSection.sections.key(2)}'
      when 3 then '#{CustomSection.sections.key(3)}'
      end) ILIKE '%#{data}%' " if data.present?
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
      ORDER BY  #{sorting_filter}
      OFFSET #{(params[:page] - 1) * params[:per_page].to_i}
      LIMIT #{params[:per_page]}
    ")
  end

  def dash_filter
    request_condition = if params[:requested].present?
                          " csa.state = #{CustomSectionApproval.states[:requested]} "
                        else
                          " csa.state = #{CustomSectionApproval.states[:approved]} "
                        end

    "SELECT DISTINCT csa.id, csa.updated_at as effect_date, csa.user_id, csa.created_at as request_date, 
    cs.section as custom_section_name, u.preferred_name,  
    sum(cs.approval_expiry_time - DATE_PART('day', now()::timestamp - csa.created_at::timestamp)) as expire_time,
    csa.state as status, csa.updated_at

    FROM custom_section_approvals as csa 
    INNER JOIN custom_sections as cs 
    ON csa.custom_section_id = cs.id AND cs.is_approval_required = TRUE 
    
    INNER JOIN users as u ON u.id = csa.user_id AND u.deleted_at IS NULL 
    
    WHERE cs.company_id = #{params[:company_id]} 
    AND #{request_condition} 
    AND csa.deleted_at IS NULL #{term_filter}  GROUP By csa.id, cs.section, u.preferred_name "
  end 

end