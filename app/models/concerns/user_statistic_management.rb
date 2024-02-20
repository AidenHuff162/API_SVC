module UserStatisticManagement
  extend ActiveSupport::Concern

  included do
    after_create :log_updated_user_id
    after_update :log_updated_user_id

    before_destroy :log_updated_user_id
  end

  private

  def updated_attributes_exists?
    updated_attributes = self.changed

    updated_attributes.delete('updated_at') if updated_attributes.include?('updated_at')
    updated_attributes.delete('tokens') if updated_attributes.include?('tokens')
    updated_attributes.delete('last_active') if updated_attributes.include?('last_active')
    updated_attributes.delete('current_sign_in_at') if updated_attributes.include?('current_sign_in_at')
    updated_attributes.delete('sign_in_count') if updated_attributes.include?('sign_in_count')

    updated_attributes.present?
  end

  def log_onboarded_user_id
    return unless Rails.env.test?.blank?

    Company::LogUserStatisticsJob.perform_async({company_id: self.company_id, user_id: self.id}, 'manage_onboarded_user')
  end

  def log_loggedin_user_id
    return unless Rails.env.test?.blank?
    Company::LogUserStatisticsJob.perform_async({company_id: self.company_id, user_id: self.id}, 'manage_loggedin_user')
  end

  def log_updated_user_id
    return unless Rails.env.test?.blank?

    Company::LogUserStatisticsJob.perform_async({object_id: self.id, object_class: self.class.name}, 'manage_updated_user')
  end
end
