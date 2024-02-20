module Pto
  class MakePtoAdjustments
    def perform company_id
      PtoAdjustment.joins(assigned_pto_policy: :pto_policy).where("pto_policies.company_id = ?", company_id).where(is_applied: false).try(:each) do |pto_adjustment|
        begin
          pto_adjustment.make_adjustment
        rescue Exception=>e
          LoggingService::GeneralLogging.new.create(Company.find_by(id: company_id), 'Make PTO Adjustments', {result: "Failed to apply adjustment with id #{pto_adjustment.id}", error: e.message}, 'PTO')           
        end
      end
    end
  end
end
