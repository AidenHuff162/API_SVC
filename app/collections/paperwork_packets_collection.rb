class PaperworkPacketsCollection < BaseCollection
  include SmartAssignmentFilters
  private

  def relation
    @relation ||= PaperworkPacket.all
  end

  def ensure_filters
    company_filter
    meta_filter
    deleted_filter
    exclude_by_ids_filter
    name_filter
    onboarding_plan_filter
    sorting_filter
    packet_connection_count_filter
    sa_filter
    custom_group_filter
    process_type_filter
    exclude_already_assigned_filter
    packet_ids
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]) } if params[:company_id]
  end

  def meta_filter
    filter { |relation| relation.where("meta::text != '{}'") }
  end

  def deleted_filter
    filter { |relation| relation.where(deleted_at: nil) }
  end

  def name_filter
    filter do |relation|
      pattern = "%#{params[:term].to_s.downcase}%"

      name_query = 'concat_ws(\' \', lower(name)) LIKE ?'

      relation.where("#{name_query}", pattern)
    end if params[:term]
  end

  def packet_connection_count_filter
    filter { |relation| relation.joins(:paperwork_packet_connections).group('paperwork_packets.id') } if params[:packet_connections]
  end

  def exclude_by_ids_filter
    filter { |relation| relation.where.not(id: params[:exclude_ids]) } if params[:exclude_ids]
  end

  def sorting_filter
     if params[:order_column] && params[:order_in]
      order_in = params[:order_in].downcase == 'asc' ? 'asc' : 'desc'
      if params[:order_column] == 'name'
        filter { |relation| relation.reorder("#{params[:order_column]} #{order_in}") }
      elsif params[:order_column] == 'type'
        filter { |relation| relation.reorder("meta -> 'type' #{order_in}") }
      elsif params[:order_column] == 'updated_at'
        filter { |relation| relation.reorder("#{params[:order_column]} #{order_in}") }
      end
    end
  end

  def sa_filter
    filter { |relation| relation.where(sa_filters) } if (params[:location_id] && params[:skip_LDE_filters].blank?) || (params[:team_id] && params[:skip_LDE_filters].blank?) || (params[:employment_status_option] && params[:skip_LDE_filters].blank?) || params[:custom_groups]
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

  def process_type_filter
    if params["process_type"]
      filter { |relation| relation.where("meta ->> 'type' = ?", params["process_type"]) }
    end
  end

  def packet_ids
    filter { |relation| relation.where(id: params[:packet_ids]) } if params[:packet_ids]
  end

  def exclude_already_assigned_filter
    filter do |relation|
      assigned_paperwork_requests = relation.joins(:paperwork_requests).where(paperwork_requests: {user_id: params["user_id"], state: ['preparing', 'assigned']}).uniq      
      assigned_upload_requests = relation.joins(:user_document_connections).where(user_document_connections: {user_id: params["user_id"], state: 'request'}).uniq
      relation = relation - assigned_paperwork_requests - assigned_upload_requests      
    end if params["user_id"].present? && params["duplication_allowed"].present? && params["duplication_allowed"].downcase == 'false'
  end

  def onboarding_plan_filter
    filter {|relation| relation.where("meta -> 'type' <@ ?", ['Onboarding', 'Offboarding'].to_s) } if params[:onboarding_plan]
  end
end
