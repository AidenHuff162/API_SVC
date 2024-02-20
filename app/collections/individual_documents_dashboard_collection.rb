class IndividualDocumentsDashboardCollection < BaseCollection
	attr_reader :params

  def initialize(params)
    @params = params
  end

  def results
    @results ||= begin
      get_due_documents
    end
  end
  
  def count
    records_count
  end

  private

  def records_count
    ActiveRecord::Base.connection.exec_query("
      #{collective_documents_filter}
      SELECT COUNT(*)
      FROM combined_documents
    ").first["count"].to_i
  end

  def term_query(tab)
    if params[:term].present?
      "AND (#{tab}.title ilike '%#{params[:term]}%' OR u.first_name ilike '%#{params[:term]}%' OR u.last_name ilike '%#{params[:term]}%' OR u.preferred_full_name ilike '%#{params[:term]}%' OR u.preferred_name ilike '%#{params[:term]}%')"
    else
      ""
    end
  end

  def collective_documents_filter
    "
      WITH combined_documents AS (
        #{paperwork_request_query}
        UNION ALL
        #{upload_requests_query}
        UNION
        #{existing_due_docs_query}
      )
    "
  end


  def get_due_documents
    @relation = ActiveRecord::Base.connection.exec_query("
      #{collective_documents_filter}
      SELECT *
      FROM combined_documents
      ORDER BY  #{params[:sort_column]} #{params[:sort_order]}
      OFFSET #{(params[:page] - 1) * params[:per_page].to_i}
      LIMIT #{params[:per_page]}
    ")
  end

  def paperwork_request_query
    "SELECT DISTINCT d.id, d.title, d.description, 0 as type, pt.representative_id, pt.is_manager_representative
    
    FROM documents as d 
    LEFT JOIN paperwork_templates as pt ON pt.document_id = d.id 
    INNER JOIN paperwork_requests as pr ON pr.document_id = d.id
    INNER JOIN users as u ON u.id = pr.user_id AND u.deleted_at IS NULL  
    WHERE d.company_id = #{params[:company_id]}
      AND d.deleted_at IS NULL AND pr.deleted_at IS NULL AND (pr.state = 'assigned' 
      OR (pr.co_signer_id IS NOT NULL AND pr.state != 'all_signed' AND pr.state != 'draft' )) " + exclude_offboarded_user_documents() + due_date_query('pr') + term_query('d')
  end

  def upload_requests_query
    "SELECT DISTINCT dcr.id, dcr.title, dcr.description, 1 as type, -1 as representative_id, FALSE as is_manager_representative

    FROM document_connection_relations as dcr 
    INNER JOIN user_document_connections as udc 
      ON udc.document_connection_relation_id = dcr.id AND udc.state = 'request'
    INNER JOIN users as u ON u.id = udc.user_id AND u.deleted_at IS NULL  
    INNER JOIN document_upload_requests as dur ON dur.document_connection_relation_id = dcr.id
    WHERE dur.company_id = #{params[:company_id]}
      AND dur.deleted_at IS NULL AND udc.deleted_at IS NULL " + exclude_offboarded_user_documents() + due_date_query('udc') + term_query('dcr')
  end

  # To handle the existing data on updating the document upload request from tool page
  def existing_due_docs_query
    "SELECT DISTINCT dcr.id, dcr.title, dcr.description, 1 as type, -1 as representative_id, FALSE as is_manager_representative 
    FROM document_connection_relations as dcr 
    INNER JOIN user_document_connections as udc ON udc.document_connection_relation_id = dcr.id AND udc.state = 'request' 
    INNER JOIN users as u ON u.company_id = #{params[:company_id]} AND u.id = udc.user_id AND u.deleted_at IS NULL 
    WHERE udc.deleted_at IS NULL " + exclude_offboarded_user_documents() + due_date_query('udc') + term_query('dcr')
  end

  def due_date_query tab
    date = Company.find(params[:company_id]).time.to_date
    params['process_type'] == 'Overdue Documents' ? "AND #{tab}.due_date < '#{date}' " : "AND (#{tab}.due_date is NULL OR #{tab}.due_date >= '#{date}') "
  end

  def exclude_offboarded_user_documents
    "AND u.state != 'inactive' AND u.current_stage != '7'"
  end
end
