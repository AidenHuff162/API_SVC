class IndividualDocumentsCollection < BaseCollection
  include SmartAssignmentFilters
	attr_reader :params
  attr_accessor :sa_filter_sub_query

  def initialize(params)
    @params = params
    @sa_filter_sub_query = sa_filter
  end

  def results
    @results ||= begin
      params["skip_pagination"].present? ? relation_without_pagination : relation
    end
  end

  def due_documents
    get_due_documents
  end

  def count
    records_count
  end

  private

  def relation_without_pagination
    @relation = ActiveRecord::Base.connection.exec_query("
      #{collective_documents_filter}
      SELECT *
      FROM combined_documents
      #{where_clause}
    ")
  end

  def relation
  	@relation = ActiveRecord::Base.connection.exec_query("
      #{collective_documents_filter}
      SELECT *
      FROM combined_documents
      #{where_clause}
      ORDER BY  #{params[:sort_column]} #{params[:sort_order]}
      OFFSET #{(params[:page] - 1) * params[:per_page].to_i}
      LIMIT #{params[:per_page]}
    ")
  end
  
  def sa_filter  
    sa_query = ''
    if params[:location_id] || params[:team_id] || params[:employment_status_option] || params[:custom_groups]
      sa_query = " AND (" + sa_filters + ")"
    end
    sa_query
  end

  def collective_documents_filter
    "
      WITH combined_documents AS (
        #{paperwork_template_query}
        UNION ALL
        #{upload_requests_query}
      )
    "    
  end

  def paperwork_template_query
    if params[:pending_hire]
      "SELECT pt.id, pt.user_id, doc.meta, pt.need_reset,
        pt.company_id, doc.title, doc.description,
        doc.updated_at, u.preferred_name, u.first_name, u.last_name,
        0 as type, pt.representative_id, pt.is_manager_representative, doc.id as document_id, 
        null as special_user, null as global, null as updated_by_first_name, null as updated_by_last_name,
        null as updated_by_preferred_name, pr.co_signer_id as paperwork_request_co_signer_id,
        pr.hellosign_signature_request_id as hellosign_signature_request_id

      FROM documents as doc
      LEFT JOIN paperwork_templates as pt ON pt.document_id = doc.id 
      INNER JOIN paperwork_requests as pr 
        ON pr.document_id = doc.id AND pr.state = 'draft' AND pr.user_id = #{params[:user_id]}
      INNER JOIN users as u ON u.id = pr.user_id AND u.company_id = #{params[:company_id]} AND u.deleted_at IS NULL  
      WHERE doc.company_id = #{params[:company_id]}
        AND doc.deleted_at IS NULL AND pr.deleted_at IS NULL"
    else
    	"SELECT pt.id, pt.user_id, doc.meta, pt.need_reset,
    		pt.company_id, doc.title, doc.description,
    		doc.updated_at, u.preferred_name, u.first_name, u.last_name,
    		0 as type, pt.representative_id, pt.is_manager_representative, pt.document_id as document_id,
        null as special_user, null as global, ub.first_name as updated_by_first_name, ub.last_name as updated_by_last_name,
        ub.preferred_name as updated_by_preferred_name, null as paperwork_request_co_signer_id,
        null as hellosign_signature_request_id

      FROM paperwork_templates as pt
    	LEFT JOIN documents as doc ON pt.document_id = doc.id
    	LEFT JOIN users as u ON pt.user_id = u.id AND u.company_id = #{params[:company_id]}
      LEFT JOIN users as ub ON pt.updated_by_id = ub.id AND ub.company_id = #{params[:company_id]}
    	WHERE pt.company_id = #{params[:company_id]} AND pt.state = 'saved'
        AND doc.meta->>'type' = '#{params[:process_type]}'
        AND pt.deleted_at IS NULL" + @sa_filter_sub_query
    end    
  end

  def upload_requests_query
    if params[:pending_hire]
      "SELECT dur.id, dur.user_id, dur.meta, dur.need_reset,
        dur.company_id, dcr.title, dcr.description,
        dcr.updated_at, u.preferred_name, u.first_name, u.last_name ,
        1 as type, -1 as representative_id, FALSE as is_manager_representative, 
        dur.document_connection_relation_id as document_id, dur.special_user_id as special_user, 
        dur.global as global, null as updated_by_first_name, null as updated_by_last_name,
        null as updated_by_preferred_name, null as paperwork_request_co_signer_id, null as hellosign_signature_request_id

      FROM document_connection_relations as dcr 
      INNER JOIN user_document_connections as udc 
        ON udc.document_connection_relation_id = dcr.id AND udc.state = 'draft' AND udc.user_id = #{params[:user_id]}
      INNER JOIN users as u ON u.id = udc.user_id AND u.company_id = #{params[:company_id]} AND u.deleted_at IS NULL
      INNER JOIN document_upload_requests as dur ON dur.document_connection_relation_id = dcr.id
      LEFT JOIN users as ub ON dur.updated_by_id = ub.id AND ub.company_id = #{params[:company_id]}
      WHERE dur.company_id = #{params[:company_id]}
        AND dur.deleted_at IS NULL AND udc.deleted_at IS NULL"
    else
    	"SELECT dur.id, dur.user_id, dur.meta, dur.need_reset,
    		dur.company_id, dcr.title, dcr.description,
    		dcr.updated_at, u.preferred_name, u.first_name, u.last_name ,
    		1 as type, -1 as representative_id, FALSE as is_manager_representative, 
        dur.document_connection_relation_id as document_id, dur.special_user_id as special_user, 
        dur.global as global, ub.first_name as updated_by_first_name, ub.last_name as updated_by_last_name,
        ub.preferred_name as updated_by_preferred_name, null as paperwork_request_co_signer_id,
        null as hellosign_signature_request_id

    	FROM document_upload_requests as dur
    	LEFT JOIN document_connection_relations as dcr
    	  ON dur.document_connection_relation_id = dcr.id
    	LEFT JOIN users as u ON dur.user_id = u.id AND u.company_id = #{params[:company_id]}
      LEFT JOIN users as ub ON dur.updated_by_id = ub.id AND ub.company_id = #{params[:company_id]}
  		WHERE dur.company_id = #{params[:company_id]}
        AND dur.meta->>'type' = '#{params[:process_type]}'
        AND dur.deleted_at IS NULL" + @sa_filter_sub_query
    end
  end


  def records_count
    ActiveRecord::Base.connection.exec_query("
      #{collective_documents_filter}
      SELECT COUNT(*)
      FROM combined_documents
      #{where_clause}
    ").first["count"].to_i
  end

  def where_clause
    if params[:term].present?
      term = ActiveRecord::Base.connection.quote("%#{params[:term]}%")
      "WHERE title ilike " + term + " "
    else
      ""
    end
  end
end
