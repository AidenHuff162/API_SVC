class InboxEmailTemplatesCollection < BaseCollection
  include SmartAssignmentFilters
  private

  def relation
    @relation ||= EmailTemplate.order_by_priority
  end

  def ensure_filters
    company_filter
    templates_filter
    notification_filter
    permission_group_filter
    type_filter
    sa_filter
    name_filter
    onboarding_filter
    offboarding_filter
    bulk_onboarding_filter
    invitation_filter
    other_filter
    sorting_filter
  end

  def company_filter
    filter { |relation| relation.where(is_temporary: false, company_id: params[:company_id]) } if params[:company_id]
  end

  def templates_filter
    filter { |relation| relation.where.not(email_type: DEFAULT_NOTIFICATION_TEMPLATES) } if !params[:notifications]
  end

  def notification_filter
    filter { |relation| relation.where(email_type: DEFAULT_NOTIFICATION_TEMPLATES) } if params[:notifications]
  end

  def permission_group_filter
    filter { |relation| relation.where("('all' = ANY (permission_group_ids) OR ?  = ANY (permission_group_ids) AND (permission_type = 'permission_group')) OR ('all' = ANY (permission_group_ids) OR ?  = ANY (permission_group_ids) AND (permission_type = 'individual'))", params['current_user'].user_role.id.to_s, params[:current_user].id.to_s) } if params[:current_user] && !params[:current_user].account_owner?
  end

  def type_filter
    filter { |relation| relation.where(email_type: params[:email_type]) } if params[:email_type]
  end

  def onboarding_filter
    filter { |relation| relation.where.not(email_type: ['offboarding']) } if params[:onboarding]
  end

  def invitation_filter
    filter { |relation| relation.where(email_type: 'invitation').reorder('id asc') } if params[:invitation]
  end

  def offboarding_filter
    filter { |relation| relation.where.not(email_type: ['invitation']) } if params[:offboarding]
  end

  def bulk_onboarding_filter
    filter { |relation| relation.where.not("schedule_options->> 'relative_key' = ANY(ARRAY['birthday', 'last day worked', 'date of termination']) AND schedule_options->> 'send_email' = '2'") } if params[:bulk_onboarding]
  end

  def sa_filter
    params.merge!(employee_type: params[:employment_status_id] || params[:employee_type])
    filter { |relation| relation.where(sa_filters) } if is_SA_enable
  end

  def sorting_filter
    if params[:order_column] && params[:order_in]
      order_in = params[:order_in].downcase == 'asc' ? 'asc' : 'desc'
      
      if params[:order_column] == 'type'
        filter { |relation| relation.reorder("email_type #{order_in}") }

      elsif params[:order_column] == 'name'
        filter { |relation| relation.reorder("name #{order_in}") }

      elsif params[:order_column] == 'modified_by'
        filter { |relation| relation.joins('LEFT OUTER JOIN "users" ON "users"."id" = "email_templates"."editor_id"').reorder("users.preferred_full_name #{order_in}") }

      end
    end
  end

  def name_filter
    data = params[:term] || params["search"]["value"] if params[:term].present? || params["search"] && params["search"]["value"]
    filter do |relation|
      pattern = "%#{data.to_s.downcase}%"
      relation.where("lower(TRIM(name)) LIKE :pattern OR lower(TRIM(email_type)) LIKE :pattern", pattern: pattern)
    end if data
  end

  def other_filter
    filter { |relation| relation.where.not(email_type: ['invitation', 'offboarding', 'Relocation', 'Promotion']) } if params[:other]
  end

  private

  def is_SA_enable
    (params[:smart_assignment].present? && ((params[:location_id].present? && params[:location_id][0] != nil) ||
    (params[:team_id].present? && params[:team_id][0] != nil) || (params[:employment_status_id].present? && params[:employment_status_id][0] != nil) || params[:custom_groups].present?))
  end
end
