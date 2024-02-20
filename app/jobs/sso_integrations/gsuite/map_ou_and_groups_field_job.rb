class SsoIntegrations::Gsuite::MapOuAndGroupsFieldJob
  include Sidekiq::Worker
  sidekiq_options :queue => :update_departments_and_locations, :retry => false, :backtrace => true

  def perform(company_id)
    company = Company.find_by(id: company_id)

    return unless company.present? && company.get_gsuite_account_info.present?
    
    ::Gsuite::ManageAccount.new.get_gsuite_ou(company)
    ::Gsuite::ManageAccount.new.get_gsuite_groups(company)
  end
end
