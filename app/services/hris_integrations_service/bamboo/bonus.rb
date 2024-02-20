class HrisIntegrationsService::Bamboo::Bonus
  attr_reader :company

  delegate :fetch_custom, :create_or_update, :create_or_update_custom, to: :tabular_data, prefix: :execute_tabular_data

  def initialize(company)
    @company = company
  end

  def fetch(bamboo_id, table_name ='customBonus')
    execute_tabular_data_fetch_custom(table_name, bamboo_id)
  end

  def create_or_update(action, bamboo_id, params, table_name='customBonus')
    execute_tabular_data_create_or_update_custom(action, table_name, bamboo_id, params)
  end

  private

  def tabular_data
    HrisIntegrationsService::Bamboo::TabularData.new company
  end
end
