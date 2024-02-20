class ProfileTemplatesCollection < BaseCollection
  private

  def relation
    @relation ||= ProfileTemplate.includes(:profile_template_custom_table_connections, :profile_template_custom_field_connections, :process_type).all.order(:name)
  end

  def ensure_filters
    company_filter
    process_type_filter
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id])} if params[:company_id]
  end

  def process_type_filter
    filter { |relation| relation.joins(:process_type).where(process_types: { name: params[:process_type] }) } if params[:process_type]
  end

  def build_array id
    array = id.present? ? [id].map(&:to_s).push('all') : ['all']
  end
end
