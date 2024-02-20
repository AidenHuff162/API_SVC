module TimeOff
  class PtoCalculationsJob < ApplicationJob
    queue_as :pto_calculations

    def perform companies_for_calculations, companies_at_end
      make_pto_calculations(Company.where(id: companies_for_calculations)) if companies_for_calculations.count > 0
      accrue_balance_at_end_of_period(Company.where(id: companies_at_end))
    end

    private

    def make_pto_calculations companies
      companies.try(:each) do |company|
        expire_carryover(company)
        renew_pto_policies(company)
        make_pto_adjustments(company)
        accrue_balance_for_companys_pto_policies(company, 0)
        deduct_pto_balance(company)
      end
    end

    def accrue_balance_at_end_of_period companies
      companies.try(:each) do |company|
        accrue_balance_for_companys_pto_policies(company, 1)
      end
    end
    
    def expire_carryover company
      begin
        Pto::ExpireCarryoverBalance.new.perform(company.id)
      rescue Exception => e
        logging.create(company, 'Expire Carryover', {result: 'Failed to expire carryover', error: e.message}, 'PTO')           
      end
    end

    def renew_pto_policies company
      begin
        Pto::RenewPtoPolicies.new.perform(company.id)
      rescue Exception => e
        logging.create(company, 'Renew Policies', {result: 'Failed to renew policies', error: e.message}, 'PTO')           
      end
    end

    def make_pto_adjustments company
      begin
        Pto::MakePtoAdjustments.new.perform(company.id)
      rescue Exception => e
        logging.create(company, 'Make Adjustments', {result: 'Failed to apply adjustments', error: e.message}, 'PTO')           
      end
    end

    def accrue_balance_for_companys_pto_policies company, period_interval
      begin
        Pto::ManagePtoBalances.new(period_interval, company).perform
        Pto::ManagePtoBalances.new(period_interval, company, true).add_initial_balance_for_policy_starting_at_custom_accrual_date
      rescue Exception => e
        logging.create(company, 'Accrue Balance', {result: 'Failed to add accruals', error: e.message}, 'PTO')           
      end
    end

    def deduct_pto_balance company
      begin
        Pto::DeductBalances.new.perform(company)
      rescue Exception => e
        logging.create(company, 'Deduct Balance', {result: 'Failed to deduct balances', error: e.message}, 'PTO')           
      end
    end

    private
    def logging
      @logging ||= LoggingService::GeneralLogging.new
    end
  end
end
