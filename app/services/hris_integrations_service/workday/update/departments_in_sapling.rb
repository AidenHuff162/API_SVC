class HrisIntegrationsService::Workday::Update::DepartmentsInSapling < ApplicationService
  include HrisIntegrationsService::Workday::Logs

  TODAY = Date.today.strftime('%B %d, %Y')

  attr_reader :user, :company, :team_id, :effective_date_id

  def initialize(user, team_id)
    @user, @company, @team_id = user, user.company, team_id
  end

  def call
    begin
      return if user.team_id == team_id

      user.update!(team_id: team_id) 
      create_snapshot
    rescue Exception => @error
      error_log("Unable to assign department to user: #{user.id}", {}, team_id)
    end
  end

  private

  def create_snapshot
    return unless company.is_using_custom_table?

    role_info_table = CustomTable.role_information(company.id)
    @effective_date_id = role_info_table.custom_fields.find_by(name: 'Effective Date').id
    return unless (applied_ctus = role_info_table.custom_table_user_snapshots.find_by(state: 'applied', user_id: user.id))

    role_info_table.custom_table_user_snapshots.create!(user_id: user.id, state: 'queue', effective_date: TODAY,
     custom_snapshots_attributes: custom_snapshots_attributes(applied_ctus), terminate_job_execution: true)
  end

  def custom_snapshots_attributes(applied_ctus)
    applied_ctus.custom_snapshots.map do |cs|
      { "#{cs.preference_field_id ? 'preference_field_id' : 'custom_field_id'}": (cs.preference_field_id || cs.custom_field_id),
       custom_field_value: cs.preference_field_id == 'dpt' ? team_id : get_custom_field_value(cs) }
    end
  end

  def get_custom_field_value(cs)
    cs.custom_field_id == effective_date_id ? TODAY : cs.custom_field_value
  end

end
