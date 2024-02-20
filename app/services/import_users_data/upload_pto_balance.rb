module ImportUsersData
  class UploadPtoBalance
    attr_reader :company, :current_user
    delegate :add_user_error_to_row, :send_feedback_email, to: :helper_service

    def initialize(**kwargs)
      @company = kwargs[:company]
      @data =  kwargs[:data] || []
      @current_user = kwargs[:current_user]
      @defected_entries = []
      @date_regex = company.get_date_regex
      @upload_date = kwargs[:upload_date].to_date.strftime(company.get_date_format)
    end

    def perform
      header = @data[0].keys
      index = 0
      @data.try(:each) do |row|
        index += 1
        make_pto_adjustments(row, index)
      rescue StandardError => e
        @defected_entries.push(row)
        add_user_error_to_row(row, "Row - #{index} - #{e.message}")
      end
      send_feedback_email(build_attrs_for_feedback_email)
    end

    def make_pto_adjustments(row, index)
      entry = row.to_hash
      user, opening_balance, effective_date, assigned_pto_policy = build_data(entry)
      if user && opening_balance && effective_date && assigned_pto_policy
        opening_balance = opening_balance.to_f
        operation = opening_balance.positive? ? 1 : 2
        assigned_pto_policy.pto_adjustments.create!(hours: opening_balance.abs, effective_date: effective_date,
                                                    creator_id: current_user.id, operation: operation,
                                                    description: 'Uploaded Through Data Upload')
      else
        @defected_entries.push(row)
        args = { user: user, opening_balance: opening_balance, effective_date: effective_date, assigned_pto_policy: assigned_pto_policy }
        add_user_error_to_row(row, "Row - #{index} - #{descriptive_error_message(args)}")
      end
    end

    def build_data(entry)
      user = company.users.where('id = ? OR email = ?',
                                  entry['User ID'].to_i, entry['Company Email'].try(:downcase)).take
      effective_date = Date.strptime(entry['Effective Date'], @date_regex)
      assigned_pto_policy = user.present? ? user.assigned_pto_policies.find_by(pto_policy_id: entry['PTO policy']) : nil
      [user, entry['Opening Balance'], effective_date, assigned_pto_policy]
    end

    def descriptive_error_message(**kwargs)
      return 'User does not exist!' if kwargs[:user].blank?
      return 'Opening Balance is missing!' if kwargs[:opening_balance].blank?
      return 'Effective Date is missing!' if kwargs[:effective_date].blank?
      return 'PTO Policy is missing!' if kwargs[:assigned_pto_policy].blank?

      ''
    end
    
    def build_attrs_for_feedback_email
      {
        data: @data, company: company, headers: @data[0].keys, upload_date: @upload_date, email: current_user.email,
        section_name: 'pto_balance', invalid_entries: @defected_entries, first_name: current_user.first_name
      }
    end

    def helper_service
      ImportUsersData::Helper.new
    end
  end
end
