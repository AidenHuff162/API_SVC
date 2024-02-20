class CustomTables::AssignMismatchCustomFieldValue
  attr_reader :user, :ctus, :company_id

  def initialize(ctus)
    @ctus = ctus
    @user = ctus.user
    @company_id = user.company.id
  end

  def perform
    ::CustomTables::AssignCustomFieldValue.new.assign_values_to_user(@ctus) if user_header_mismatch(@ctus)
  end

  private

  def user_header_mismatch(ctus)
    if @user.present?
      user_applied_ctus = @user.custom_table_user_snapshots.where(state: "applied", custom_table_id: @ctus.custom_table_id)
      return false if user_applied_ctus.count > 1

      manager_id = get_header_info('man')

      loc_id = get_header_info('loc')
      
      team_id = get_header_info('dpt')
      
      manager_mismatch(manager_id) || location_mismatch(loc_id) || team_mismatch(team_id) || job_title_mismatch
    end
  end

  def get_header_info(field_id)
    @ctus.custom_snapshots.where(preference_field_id: field_id).try(:take).try(:custom_field_value).to_s
  end

  def manager_mismatch(manager_id)
    manager_id != @user.manager_id.to_s && User.find_by(id: manager_id, company_id: company_id)&.active?
  end

  def location_mismatch(loc_id)
    loc_id != @user.location_id.to_s && Location.find_by(id: loc_id, company_id: company_id).present?
  end

  def team_mismatch(team_id)
    team_id != @user.team_id.to_s && Team.find_by(id: team_id, company_id: company_id).present?
  end

  def job_title_mismatch
    @ctus.custom_snapshots.where(preference_field_id: 'jt').try(:take).try(:custom_field_value).to_s != @user.title.to_s
  end
end
