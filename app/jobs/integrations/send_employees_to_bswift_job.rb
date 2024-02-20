module Integrations
  class SendEmployeesToBswiftJob
    include Sidekiq::Worker
    sidekiq_options queue: :default, retry: false, backtrace: true

    def perform(company_id)
      company = Company.find_by_id(company_id)
      BswiftService::Main.new(company).perform if company
    end

  end
end
