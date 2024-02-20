class EmailTemplatesCollection < BaseCollection
  private

  def relation
    @relation ||= EmailTemplate.where(is_temporary: false)
  end

  def ensure_filters
    company_filter
    type_filter
    notification_filter
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]) } if params[:company_id]
  end

  def type_filter
    filter { |relation| relation.where(email_type: params[:email_type]) } if params[:email_type]
  end

  def notification_filter
    filter { |relation| relation.where(is_temporary: false, email_type: DEFAULT_NOTIFICATION_TEMPLATES) } if params[:notifications]
  end

  def offboarding_filter
    filter { |relation| relation.where.not(email_type: DEFAULT_NOTIFICATION_TEMPLATES).where.not(email_type: ['invitation', 'welcome_email']) } if params[:offboarding]
  end
end