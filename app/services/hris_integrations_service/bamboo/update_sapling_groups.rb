class HrisIntegrationsService::Bamboo::UpdateSaplingGroups
  attr_reader :company

  def initialize(company)
    @company = company
    @bamboo_integration = company.integration_instances.find_by(api_identifier: 'bamboo_hr', state: :active)
  end

  def perform
    update_sapling_departments
    update_sapling_locations
    update_sapling_divisions
  end

  private

  def update_sapling_departments
    begin
      response = HrisIntegrationsService::Bamboo::Department.new(company).fetch
      response.try(:each) { |name| company.teams.create(name: name.strip) if !company.teams.where('name ILIKE ?', name.strip).exists? }
      @bamboo_integration.update_column(:synced_at, DateTime.now) if @bamboo_integration
      log('Update - Sapling Division Overnight', {bamboo: 'get meta/lists'}, {bamboo: response}, 200)
    rescue Exception => exception
      log('Update - Sapling Division Overnight', {bamboo: 'get meta/lists'}, {bamboo: exception.message}, 500)
    end
  end

  def update_sapling_locations
    begin
      response = HrisIntegrationsService::Bamboo::Location.new(company).fetch
      response.try(:each) { |name| company.locations.create(name: name.strip) if !company.locations.where('name ILIKE ?', name.strip).exists? }
      @bamboo_integration.update_column(:synced_at, DateTime.now) if @bamboo_integration
      log('Update - Sapling Division Overnight', {bamboo: 'get meta/lists'}, {bamboo: response}, 200)
    rescue Exception => exception
      log('Update - Sapling Division Overnight', {bamboo: 'get meta/lists'}, {bamboo: exception.message}, 500)
    end
  end

  def update_sapling_divisions
    division = company.custom_fields.find_by(name: "Division", integration_group: [CustomField::integration_groups[:bamboo], CustomField::integration_groups[:adp_wfn_profile_creation_and_bamboo_two_way_sync]])
    if !division.blank?
      begin
        response = HrisIntegrationsService::Bamboo::Division.new(company, division).fetch
        response.try(:each) { |option| division.custom_field_options.create(option: option.strip) if !division.custom_field_options.where('option ILIKE ?', option.strip).exists? }
        @bamboo_integration.update_column(:synced_at, DateTime.now) if @bamboo_integration
        log('Update - Sapling Division Overnight', {bamboo: 'get meta/lists'}, {bamboo: response}, 200)
      rescue Exception => exception
        log('Update - Sapling Division Overnight', {bamboo: 'get meta/lists'}, {bamboo: exception.message}, 500)
      end
    end
  end

  def log(action, request, response, status)
    LoggingService::IntegrationLogging.new.create(@company, 'BambooHR', action, request, response, status)
  end
end
