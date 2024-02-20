module Pto
  class FilterPtoDataByTypeOrYear

    def initialize type, year, user_id, reset, operation_type
      @year = year.present? ? year.to_i : nil
      @type = type.present? ? type.to_i : nil
      @user_id = user_id
      @reset_search = reset
      @operation_type = operation_type
      @user = User.find(user_id)
      @filter_result = {}
    end

    def perform
      @filter_result[:history_entries] = (fetch_matching_adjustments + fetch_matching_pto_requests).uniq if @operation_type == "Usage"
      @filter_result[:history_entries] = fetch_matching_accruals.uniq if @operation_type == "Accrual"
      serialize_response
      @filter_result
    end

    private

    def fetch_matching_pto_requests
      date = @user.company.time.to_date
      statuses = @year.present? && date.year < @year ? [PtoRequest.statuses['denied'], PtoRequest.statuses['cancelled']] :  PtoRequest.statuses.values
      if reset_search?
        @user.pto_requests.individual_requests.where(status: statuses).historic_requests(date).joins("LEFT JOIN pto_policies on pto_requests.pto_policy_id = pto_policies.id").where('extract(year from begin_date) = ? OR extract(year from end_date) = ?', date.year(), date.year()).uniq
      else
        if @type.blank? and @year.present?
          @user.pto_requests.individual_requests.where(status: statuses).historic_requests(date).joins("LEFT JOIN pto_policies on pto_requests.pto_policy_id = pto_policies.id").where('extract(year from begin_date) = ? OR extract(year from end_date) = ?', @year, @year).uniq
        elsif @type.present? and @year.blank?
          @user.pto_requests.individual_requests.where(status: statuses).historic_requests(date).joins("LEFT JOIN pto_policies on pto_requests.pto_policy_id = pto_policies.id").where("pto_policies.policy_type = ?", @type).uniq
        else
          @user.pto_requests.individual_requests.where(status: statuses).historic_requests(date).joins("LEFT JOIN pto_policies on pto_requests.pto_policy_id = pto_policies.id").where("extract(year from begin_date) = ? and pto_policies.policy_type = ?", @year, @type).uniq
        end
      end
    end

    def fetch_matching_adjustments

      if reset_search?
        PtoAdjustment.joins(:assigned_pto_policy).where("assigned_pto_policies.user_id = ? and (extract(year from effective_date) = ?) and is_applied = ?", @user_id, @user.company.time.year(), true).uniq
      else
        if @type.blank? and @year.present?
          PtoAdjustment.joins(:assigned_pto_policy).where("assigned_pto_policies.user_id = ? and (extract(year from effective_date) = ?) and is_applied = ?", @user_id, @year, true).uniq
        elsif @type.present? and @year.blank?
          PtoAdjustment.joins(assigned_pto_policy: :pto_policy).where("assigned_pto_policies.user_id = ? and is_applied = ? and pto_policies.policy_type = ?", @user_id, true, @type).uniq
        else
          PtoAdjustment.joins(assigned_pto_policy: :pto_policy).where("assigned_pto_policies.user_id = ? and is_applied = ? and pto_policies.policy_type = ? and (extract(year from effective_date) = ?)", @user_id, true, @type, @year).uniq
        end
      end
    end

    def fetch_matching_accruals
      date = @user.company.time.to_date
      if reset_search?
        PtoBalanceAuditLog.joins(:assigned_pto_policy).where("assigned_pto_policies.user_id = ? and pto_balance_audit_logs.description LIKE 'Accr%' AND extract(year from pto_balance_audit_logs.balance_updated_at) = ? ", @user_id, date.year()).uniq
      else
        if @type.blank? and @year.present?
          PtoBalanceAuditLog.joins(:assigned_pto_policy).where("assigned_pto_policies.user_id = ? and pto_balance_audit_logs.description LIKE 'Accr%' AND extract(year from pto_balance_audit_logs.balance_updated_at) = ? ", @user_id, @year).uniq
        elsif @type.present? and @year.blank?
          PtoBalanceAuditLog.joins(assigned_pto_policy: :pto_policy).where("assigned_pto_policies.user_id = ? and pto_balance_audit_logs.description LIKE 'Accr%' and pto_policies.policy_type = ?", @user_id, @type).uniq
        else
          PtoBalanceAuditLog.joins(assigned_pto_policy: :pto_policy).where("assigned_pto_policies.user_id = ? and pto_balance_audit_logs.description LIKE 'Accr%' and pto_policies.policy_type = ? and (extract(year from pto_balance_audit_logs.balance_updated_at) = ?)", @user_id, @type, @year).uniq
        end
      end
    end


    def serialize_response
      @filter_result[:history_entries] = @filter_result[:history_entries].map { |object| serialize_object_by_class(object) }
    end

    def serialize_object_by_class object
      if object.class.name == 'PtoRequest'
        PtoRequestSerializer::Basic.new(object)
      elsif object.class.name == 'PtoAdjustment'
        PtoAdjustmentSerializer::Basic.new(object)
      elsif object.class.name == 'PtoBalanceAuditLog'
        PtoBalanceAuditLogSerializer::Basic.new(object)
      end
    end

    def reset_search?
      @reset_search == 'true'
    end


  end
end
