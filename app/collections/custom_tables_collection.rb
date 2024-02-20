class CustomTablesCollection < BaseCollection
  private

  def relation
    @relation ||= CustomTable.all.order(name: :asc)
  end

  def ensure_filters
    company_filter
    enabled_all_tables
    custom_tables_filter
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]) } if params[:company_id]
  end

  def custom_tables_filter
    filter { |relation| relation.where(id: params[:custom_table_ids]) } if params[:is_home_page] || params[:is_reporting_page]
  end

  def enabled_all_tables
    filter { |relation| relation.where.not(custom_table_property: CustomTable.custom_table_properties[:general]) } if !params[:enable_custom_table_approval_engine]
  end
end
