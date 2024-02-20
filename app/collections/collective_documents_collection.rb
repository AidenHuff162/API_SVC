class CollectiveDocumentsCollection
  attr_reader :params

  def initialize(params)
    @params = params
  end

  def results
    @results ||= begin
      relation
    end
  end

  def count
    records_count
  end

  private

  def paperwork_requests_query
    "
      SELECT
        pr.id as id,
        CASE
          WHEN pp.id IS NOT NULL AND pp.packet_type = 0  AND pr.co_signer_id IS NULL THEN pp.name
          ELSE documents.title
        END AS title,
        creator.preferred_full_name AS created_by,
        pr.created_at,
        'paperwork_request' AS document_type,
        pr.state,
        pr.user_id,
        pr.co_signer_id,
        pr.signed_document,
        pr.unsigned_document,
        pr.requester_id AS creator_id,
        documents.description,
        pr.hellosign_signature_request_id,
        CASE
          WHEN co_signer.id IS NOT NULL THEN co_signer.preferred_full_name ELSE ''
        END AS co_signer_name,
        CASE
          WHEN pp.id IS NOT NULL AND (pp.packet_type = 1 OR pr.co_signer_id IS NOT NULL) THEN pp.name
          ELSE NULL
        END AS packet_name,
        pr.due_date AS due_date

      FROM paperwork_requests AS pr
      INNER JOIN documents ON documents.id = pr.document_id
      LEFT JOIN users AS creator ON creator.id = pr.requester_id
      LEFT JOIN paperwork_packets AS pp ON pp.id = pr.paperwork_packet_id
      LEFT JOIN users AS co_signer ON co_signer.id = pr.co_signer_id
      WHERE ((pr.co_signer_id = #{params[:user_id]} AND pr.state = 'signed') OR pr.user_id = #{params[:user_id]})
        AND pr.state <> 'draft'
        AND pr.deleted_at IS NULL
    "
  end

  def upload_requests_query
    "
      SELECT
        udc.id as id,
        dcr.title,
        creator.preferred_full_name AS created_by,
        udc.created_at,
        'upload_request' AS document_type,
        udc.state,
        udc.user_id,
        NULL AS co_signer_id,
        NULL AS signed_document,
        NULL AS unsigned_document,
        udc.created_by_id AS creator_id,
        dcr.description,
        NULL AS hellosign_signature_request_id,
        NULL AS co_signer_name,
        CASE
          WHEN pp.id IS NOT NULL THEN pp.name
          ELSE NULL
        END AS packet_name,
        udc.due_date AS due_date

      FROM user_document_connections AS udc
        INNER JOIN document_connection_relations AS dcr ON dcr.id = udc.document_connection_relation_id
        LEFT JOIN users AS creator ON creator.id = udc.created_by_id
        LEFT JOIN paperwork_packets AS pp ON pp.id = udc.packet_id
        WHERE udc.user_id = #{params[:user_id]}
          AND udc.deleted_at IS NULL
          AND udc.state != 'draft'
    "
  end

  def personal_documents_query
    "
      SELECT
        pd.id as id,
        pd.title,
        creator.preferred_full_name AS created_by,
        pd.created_at,
        'personal_document' AS document_type,
        NULL AS state,
        pd.user_id,
        NULL AS co_signer_id,
        NULL AS signed_document,
        NULL AS unsigned_document,
        pd.created_by_id AS creator_id,
        pd.description,
        NULL AS hellosign_signature_request_id,
        NULL AS co_signer_name,
        NULL AS packet_name,
        NULL AS due_date

      FROM personal_documents AS pd
      LEFT JOIN users AS creator ON creator.id = pd.created_by_id
      WHERE pd.user_id = #{params[:user_id]}
        AND pd.deleted_at IS NULL
    "
  end

  def collective_documents_filter
    "
      WITH combined_documents AS (
        #{paperwork_requests_query}
        UNION ALL
        #{upload_requests_query}
        UNION ALL
        #{personal_documents_query}
      )
    "
  end

  def relation
    @relation = ActiveRecord::Base.connection.exec_query("
      #{collective_documents_filter}
      SELECT *
      FROM combined_documents
      #{where_clause}
      ORDER BY #{params[:order_column]} #{params[:order_in]}
      OFFSET #{(params[:page] - 1) * params[:per_page]}
      LIMIT #{params[:per_page]}
    ")
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
      term = params[:term].gsub("'", "''")
      "WHERE title ilike '%#{term}%'"
    else
      ""
    end
  end
end




