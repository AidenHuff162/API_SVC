class MauJob
  include Sidekiq::Worker
  
  def perform
    return if Date.today != Date.today.end_of_month
    begin
      Company.find_each do |company|
        mau_count = company.users.where("state = 'active' AND super_user = false AND last_active BETWEEN ? AND ?", Date.today.beginning_of_month, Date.today.end_of_month).count
        mauh = MonthlyActiveUserHistory.find_or_create_by(date_logged: Date.today, company_id: company.id)
        mauh.update(mau_count: mau_count)
        LoggingService::GeneralLogging.new.create(company, 'MonthlyActiveUserHistory', {result: mauh})
      end
    rescue Exception => e
      LoggingService::GeneralLogging.new.create(nil, 'MonthlyActiveUserHistory', {result: 'Failed to add mau', error: e.message})
    end
  end
end
