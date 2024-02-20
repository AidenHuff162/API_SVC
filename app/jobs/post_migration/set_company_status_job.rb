module PostMigration
  class SetCompanyStatusJob
    include Sidekiq::Worker
    sidekiq_options queue: :company_state, retry: false, backtrace: true

    def perform(company_id, checker = nil)
      company = Company.find_by(id: company_id)

      if checker.present?
        company.update!(account_state: 'inactive', migration_status: 'in_progress')
      else
        company.update!(account_state: 'active', migration_status: 'completed')
      end
    end
  end
end
