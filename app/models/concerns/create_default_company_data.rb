module CreateDefaultCompanyData
  extend ActiveSupport::Concern

  def create_default_profile_template
    begin
      process_type = self.process_types.where(name: ProcessType::ONBOARDING).take
      new_template = self.profile_templates.create!(name: 'US Onboarding Template', process_type_id: process_type.id, meta: {team_id: ['all'], location_id: ['all'], employee_type: ['all']})
      self.custom_fields.try(:each_with_index) do |custom_field, i|
        new_template.profile_template_custom_field_connections.create(custom_field_id: custom_field.id, position: i)
      end
      self.prefrences['default_fields'].try(:each_with_index) do |default_field, i|
        new_template.profile_template_custom_field_connections.create(default_field_id: default_field['id'], position: i)
      end
      self.custom_tables.try(:each_with_index) do |custom_table, i|
        new_template.profile_template_custom_table_connections.create(custom_table_id: custom_table.id, position: i)
      end
    rescue Exception => e
      create_log('Create Default US Onboarding Profile Template', {error: e.message})
    end
  end 

  def create_log(action, params)
    LoggingService::GeneralLogging.new.create(self, action, params)
  end

end

