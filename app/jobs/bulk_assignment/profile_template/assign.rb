module BulkAssignment::ProfileTemplate
  class Assign
    include Sidekiq::Worker
    sidekiq_options queue: :manage_template_assignment, backtrace: true

    def perform(kwargs)
      kwargs.transform_keys!(&:to_sym)
      return if (company = Company.find_by_id(kwargs[:company_id])).blank? || (kwargs[:users].blank?)

      users = company.users.where("id IN (?) AND (onboarding_profile_template_id IS NULL OR onboarding_profile_template_id != ?)", kwargs[:users], kwargs[:template_id])
      users.find_each do |user|
        begin
          user.change_onboarding_profile_template(kwargs[:template_id], kwargs[:remove_existing_values])
        rescue Exception => e
          LoggingService::GeneralLogging.new.create(company, 'Bulk Assign Profile Template', { user: user.id, error: e.message })
        end
      end
    end
  end
end
