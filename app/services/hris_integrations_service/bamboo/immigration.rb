class HrisIntegrationsService::Bamboo::Immigration
  attr_reader :company

  delegate :fetch_custom, :create_or_update_custom, to: :tabular_data, prefix: :execute_tabular_data

  def initialize(company)
    @company = company
  end

  def fetch(bamboo_id)
    execute_tabular_data_fetch_custom('customImmigration', bamboo_id)
  end

  def create_or_update(action, bamboo_id, params)
    execute_tabular_data_create_or_update_custom(action, 'customImmigration', bamboo_id, params)
  end

  private

  def tabular_data
    HrisIntegrationsService::Bamboo::TabularData.new company
  end
end
