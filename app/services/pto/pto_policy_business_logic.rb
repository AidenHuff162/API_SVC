module Pto
  class PtoPolicyBusinessLogic
    attr_reader :params, :company

    def initialize params, company
      @params = params
      @company = company
    end

    def create_pto_policy
      position = @company.pto_policies.max_by { |d| d.position }.position + 1 rescue 0
      pto_policy = @company.pto_policies.build(@params.merge({position: position}))
      return policy_invalid(pto_policy) if check_policy_tenureship_duplication?
      pto_policy.save
      pto_policy
    end

    def update_pto_policy
      pto_policy = @company.pto_policies.find_by_id(@params['id'])
      if pto_policy.present?
        return policy_invalid(pto_policy) if check_policy_tenureship_duplication?
        pto_policy.update(@params)
        pto_policy
      else
        nil
      end
    end

    def upload_balance
      begin
        file = UploadedFile.find_by(id: @params['file']['id'])
        pto_policy = @company.pto_policies.find_by_id(@params['id'])
        creator_id = @params['creator_id']
        if file && file.file
          CSV.parse(file.file.read, headers: true) do |row|
            entry = row.to_hash
            next if entry['Company Email'].blank?
            email = entry['Company Email'].try(:downcase)
            opening_balance = entry['Opening Balance']
            effective_date = Date.strptime(entry['Effective Date'], '%m/%d/%Y')  rescue nil
            user = @company.users.where(email: email).last
            if user && opening_balance && effective_date && creator_id
              assigned_pto_policy = pto_policy.assigned_pto_policies.where(user_id: user.id).last
              operation = opening_balance.to_i.positive? ? 1 : 2
              assigned_pto_policy.pto_adjustments.find_or_create_by(hours: opening_balance.to_f.abs, effective_date: effective_date, creator_id: creator_id, operation: operation, description: 'Uploaded Through CSV') if assigned_pto_policy.present?
            end
          end
        end
      rescue Exception => e
        LoggingService::GeneralLogging.new.create(@company, 'TimeOff Balance Uploader', {error: e.message}, 'PTO')
      end
    end

    def enable_disable_policy
      pto_policy = @company.pto_policies.find_by_id(@params['id'])
      pto_policy.is_enabled = @params['is_enabled']
      pto_policy.save
      pto_policy
    end

    private
    def policy_invalid pto_policy
      pto_policy.errors.add(" ", I18n.t('errors.policy_tenureship_duplication').to_s)
      return pto_policy
    end

    def check_policy_tenureship_duplication?
      return false if (policy_tenureships = @params["policy_tenureships_attributes"]).blank? || (active_tenureships = @params["policy_tenureships_attributes"].select{ |a| a["_destroy"] == nil }).blank? || (unique_tenureships = active_tenureships.uniq {|a| a["year"]}).size == active_tenureships.size
      return true
    end
  end
end
