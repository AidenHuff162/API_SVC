module GdprManagement
  extend ActiveSupport::Concern

  def enforce_general_data_protection_regulation(regulation, is_updating = false)
    locations = fetch_locations_lies_in_regulation_action_location(regulation)
    return unless locations.present?

    locations.update_all(is_gdpr_imposed: true)
    location_ids = regulation.action_location.include?('all') ? locations.pluck(:id).push(nil) : locations.pluck(:id)

    if is_updating.present? && !regulation.action_location.include?('all')
      non_action_locations = regulation.company.locations.where.not(id: locations.pluck(:id))
      non_action_locations.update_all(is_gdpr_imposed: false)
      remove_enforced_general_data_protection_regulation(regulation.company, non_action_locations.pluck(:id).push(nil))
    end

    terminated_users = fetch_terminated_users_lies_in_regulation_action_location(regulation.company, location_ids)
    terminated_users.try(:each) { |terminated_user| terminated_user.update_column(:gdpr_action_date, ((terminated_user.termination_date || Date.today) + regulation.action_period.year)) }
  end

  def update_enforced_general_data_protection_regulation(regulation, is_location_changed = false)
    if is_location_changed.present?
      if regulation.action_location.present?
        enforce_general_data_protection_regulation(regulation, true)
      else
        regulation.company.locations.update_all(is_gdpr_imposed: false)
        remove_enforced_general_data_protection_regulation(regulation.company)
      end
    else
      imposed_users = fetch_general_data_protection_regulation_imposed_users(regulation.company)
      imposed_users.try(:each) { |imposed_user| imposed_user.update_column(:gdpr_action_date, (imposed_user.termination_date || Date.today) + regulation.action_period.year) }
    end
  end

  def update_enforced_general_data_protection_regulation_on_location_deletion(location)
    regulation = location.company.general_data_protection_regulation
    if regulation.present? && !regulation.action_location.include?('all') && regulation.action_location.include?(location.id.to_s)
      remove_enforced_general_data_protection_regulation(location.company, [location.id])
    end
    location.company.users.with_deleted.where(location_id: location.id).update_all(location_id: nil)
  end

  def enforce_general_data_protection_regulation_on_termination_date_change(user)
    regulation = user.company.general_data_protection_regulation
    return unless can_apply_regulation?(regulation, user)

    user.update_column(:gdpr_action_date, (user.termination_date || Date.today) + regulation.action_period.year)
  end

  def enforce_general_data_protection_regulation_on_location_change(user)
    regulation = user.company.general_data_protection_regulation

    if can_apply_regulation?(regulation, user)
      user.update_column(:gdpr_action_date, (user.termination_date || Date.today) + regulation.action_period.year)
    else
      user.update_column(:gdpr_action_date, nil)
    end
  end

  private

  def fetch_locations_lies_in_regulation_action_location(regulation)
    regulation.action_location.include?('all') ? regulation.company.locations.all : regulation.company.locations.where(id: regulation.action_location)
  end

  def fetch_terminated_users_lies_in_regulation_action_location(company, location_ids)
    User.with_deleted.where(company_id: company.id, location_id: location_ids, current_stage: User.current_stages[:departed], is_gdpr_action_taken: false, gdpr_action_date: nil).where.not(termination_date: nil)
  end

  def fetch_general_data_protection_regulation_imposed_users(company)
    User.with_deleted.where(company_id: company.id, is_gdpr_action_taken: false).where.not(gdpr_action_date: nil)
  end

  def remove_enforced_general_data_protection_regulation(company, location_ids = [])
    imposed_users = fetch_general_data_protection_regulation_imposed_users(company)
    return unless imposed_users.count > 0

    imposed_users = imposed_users.where(location_id: location_ids) if location_ids.present?

    return unless imposed_users.count > 0
    imposed_users.update_all(gdpr_action_date: nil)
  end

  def can_apply_regulation?(regulation, user)
    return regulation.present? && regulation.action_location.present? && (regulation.action_location.include?('all') ||
      (user.location.present? && regulation.action_location.include?(user.location.id.to_s)))
  end
end
