class HrisIntegrationsService::Bamboo::Doordash::Bonus < HrisIntegrationsService::Bamboo::Bonus

  def initialize(company)
    super(company)
  end

  def create_or_update(action, bamboo_id, params, table_name='bonus')
    execute_tabular_data_create_or_update(action, table_name, bamboo_id, params)
  end
end
