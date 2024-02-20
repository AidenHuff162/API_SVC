class PaperworkTemplatesCollection < BaseCollection
  private

  def relation
    @relation ||= PaperworkTemplate.all
  end

  def ensure_filters
    company_filter
    state_filter
    title_filter
    exclude_by_ids_filter
    include_by_ids_filter
    representative_filter
    onboarding_plan_filter
    sorting_filter
    exclude_by_user_id_filter
    employee_type_filter
    team_filter
    location_filter
    custom_group_filter
    type_filter
    exclude_already_assigned_filter
  end

  def state_filter
    filter { |relation| relation.where(state: params[:state])} if params[:state]
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]) } if params[:company_id]
  end

  def exclude_by_user_id_filter
    filter do |relation|
      user_relation = relation.joins(:document).joins("LEFT JOIN paperwork_requests ON paperwork_requests.document_id = documents.id AND paperwork_requests.state <> 'draft' AND paperwork_requests.deleted_at IS NULL").where("paperwork_requests.user_id = ?", params[:exclude_by_user_id])
      relation = relation - user_relation
    end if params[:exclude_by_user_id]
  end

  def title_filter
    filter do |relation|
      pattern = "%#{params[:term].to_s.downcase}%"

      title_query = 'concat_ws(\' \', lower(documents.title)) LIKE ?'

      relation.joins(:document).where("#{title_query}", pattern)
    end if params[:term]
  end

  def exclude_by_ids_filter
    filter { |relation| relation.where.not(id: params[:exclude_ids]) } if params[:exclude_ids]
  end

  def include_by_ids_filter
    filter { |relation| relation.where(id: params[:include_ids]) } if params[:include_ids]
  end

  def representative_filter
    filter { |relation| relation.where(representative_id:  params[:representative_id]) } if params[:representative_id]
  end

  def sorting_filter
    if params[:order_column] && params[:order_in]
      order_in = params[:order_in].downcase == 'asc' ? 'asc' : 'desc'

      if params[:order_column] == 'document.title'
        filter { |relation| relation.joins('LEFT OUTER JOIN "documents" ON "paperwork_templates"."document_id" = "documents"."id"').reorder("documents.title #{order_in}") }
      elsif params[:order_column] == 'document.type'
        filter { |relation| relation.joins('LEFT OUTER JOIN "documents" ON "paperwork_templates"."document_id" = "documents"."id"').reorder("documents.meta -> 'type' #{order_in}") }
      end
    end
  end

  def employee_type_filter
    if params["employment_status_option"]
      filter { |relation| relation.joins(:document).where("(documents.meta -> 'employee_type')  @> ? OR (documents.meta -> 'employee_type')  @> ?",['all'].to_s, params["employment_status_option"].to_s) }
    end
  end

  def team_filter
    if params["team_id"]
      filter { |relation| relation.joins(:document).where("(documents.meta -> 'team_id')  @> ? OR (documents.meta -> 'team_id')  @> ?", ['all'].to_s, params["team_id"].map{|p| p.to_i}.to_s) }
    end
  end

  def location_filter
    if params["location_id"]
      filter { |relation| relation.joins(:document).where("(documents.meta -> 'location_id')  @> ? OR (documents.meta -> 'location_id')  @> ?", ['all'].to_s, params["location_id"].map{|p| p.to_i}.to_s) }
    end
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
        filter { |relation| relation.joins(:document).where("(documents.meta -> '#{key}')  @> ? OR (documents.meta -> '#{key}')  @> ?", ['all'].to_s, custom_groups["#{key}"].to_s) }
      end
    end
  end

  def type_filter
    if params["template_type"]
      filter { |relation| relation.joins(:document).where("(documents.meta -> 'type')  <@ ?", params["template_type"].to_s) }
    end
  end

  def exclude_already_assigned_filter
    filter do |relation|
      assigned_templates = relation.joins(:document).joins("LEFT JOIN paperwork_requests ON paperwork_requests.document_id = documents.id AND paperwork_requests.state IN ('preparing','assigned') AND paperwork_requests.deleted_at IS NULL").where("paperwork_requests.user_id = ?", params["user_id"])
      relation = relation - assigned_templates
    end if params["user_id"].present? && params["duplication_allowed"].present? && params["duplication_allowed"].downcase == 'false'
  end

  def onboarding_plan_filter
    filter { |relation| relation.joins(:document).where("(documents.meta -> 'type')  <@ ?", ['Onboarding', 'Offboarding'].to_s) } if params[:onboarding_plan]
  end

end
