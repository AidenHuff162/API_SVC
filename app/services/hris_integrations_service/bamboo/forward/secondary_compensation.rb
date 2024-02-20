class HrisIntegrationsService::Bamboo::Forward::SecondaryCompensation
  attr_reader :company

  delegate :fetch, :create_or_update, to: :tabular_data, prefix: :execute_tabular_data

  def initialize(company)
    @company = company
  end

  def fetch(bamboo_id, table_name ='customSecondaryCompensation')
    execute_tabular_data_fetch(table_name, bamboo_id)
  end

  def create_or_update(action, bamboo_id, params, table_name='customSecondaryCompensation')
    execute_tabular_data_create_or_update(action, table_name, bamboo_id, params)
  end

  private

  def tabular_data
    HrisIntegrationsService::Bamboo::TabularData.new company
  end
end
