class DeleteCompany < ApplicationJob
  queue_as :delete_company

  def perform(company_id)
    company = Company.find_by(id: company_id)
    begin
      company.really_destroy!
    #:nocov:
    rescue Exception=>e
      logger.info "Error while deleting company #{company.name}"
      logger.info e.message
      LoggingService::GeneralLogging.new.create(company, 'Tenant Deletion ', {result: 'Failed to delete Company', error: e.message})
    end
    #:nocov:
  end
end
