# frozen_string_literal: true

module ImportUsersData
  # this service will create PTO Requests uploaded through flat file.
  class UploadPtoRequests
    attr_accessor :upload_date, :company, :pto_policies, :current_user

    delegate :add_user_error_to_row, :send_feedback_email, to: :helper_service

    def initialize(**kwargs)
      @company = kwargs[:company]
      @data = kwargs[:data] || []
      @current_user = kwargs[:current_user]
      @failed_rows = []
      @user = nil
      @upload_date = kwargs[:upload_date].to_date.strftime(company.get_date_format)
      @pto_policies = company.pto_policies.where(id: @data.map { |row| row['PTO policy'] })
    end

    def perform
      header = @data[0].keys
      index = 0
      @data.try(:each) do |row|
        index += 1
        entry = row.to_hash
        manage_pto_request_creation(entry, index)
      rescue StandardError => e
        failed_list(entry['Company Email'], e.message.to_s, get_profile_link(@user&.id), row, index)
      end
      send_feedback_email(build_attrs_for_feedback_email)
    end

    private

    def build_attrs_for_feedback_email
      {
        data: @data, company: company, headers: @data[0].keys, upload_date: @upload_date, email: current_user.email,
        section_name: 'pto_request', invalid_entries: @failed_rows, first_name: current_user.first_name
      }
    end

    def manage_pto_request_creation(pto_request_data, index)
      return if pto_request_data['User ID'].blank? && pto_request_data['Company Email'].blank?

      initialize_required_variables(pto_request_data)
      if check_req_variables_presence?
        args = { company_email: pto_request_data['Company Email'], comments: pto_request_data['Comments'],
                 pto_request_data: pto_request_data, index: index }
        create_and_update_pto_request(args)
      else
        failed_list(pto_request_data['Company Email'], check_failing_validations, get_profile_link(@user&.id), pto_request_data, index)
      end
    end

    def initialize_required_variables(entry)
      @balance_hours = entry['Balance hours'].to_f
      @status = entry['Status']
      @begin_date = format_date(entry['Begin date'])
      @end_date = format_date(entry['End date'])
      @user = company.users.where('id = ? OR email = ?', entry['User ID'].to_i, entry['Company Email']&.downcase).take
      @pto_policy = pto_policies.where(id: entry['PTO policy']).take
      @assigned_pto_policy = @user&.assigned_pto_policies&.find_by(pto_policy_id: @pto_policy&.id)
      @pto_balance_deducted = entry['Deduct balance'].to_i.zero? || %w[denied cancelled].include?(@status) ? true : false
      @partial_day_included = (@begin_date == @end_date && @pto_policy&.half_day_enabled && @balance_hours < @pto_policy&.working_hours)
    end

    def create_and_update_pto_request(**kwargs)
      User.current = @user
      if kwargs[:comments]
        comments_attributes = { comments_attributes: [{ "description": kwargs[:comments], "commenter_id": @user.id,
                                                        mentioned_users: [] }] }
      end
      created_pto_request = create_pto_request(comments_attributes || {})

      return if created_pto_request.errors.messages.present? && failed_list(kwargs[:company_email],
                                                                            check_failing_validations(created_pto_request.errors.messages.values.flatten),
                                                                            get_profile_link(@user.id), kwargs[:pto_request_data], kwargs[:index])

      update_pto_request_status({ user_email: kwargs[:company_email], pto: created_pto_request, user_id: @user.id, status: @status,
                                  pto_request_data: kwargs[:pto_request_data], index: kwargs[:index] })
    end

    def create_pto_request(comments_attributes)
      pto_request_data = { balance_hours: @balance_hours, user_id: @user.id, pto_policy_id: @pto_policy.id,
                           begin_date: @begin_date, end_date: @end_date, partial_day_included: @partial_day_included,
                           status: 0, balance_deducted: @pto_balance_deducted, skip_email: true }
                         .merge(comments_attributes)
      PtoRequestService::RestOps::CreateRequest.new(pto_request_data.with_indifferent_access, @user.id).perform
    end

    def update_pto_request_status(**kwargs)
      pto = kwargs[:pto]
      if pto.errors.empty?
        if %w[denied cancelled].include?(kwargs[:status])
          pto.update_column(:balance_deducted, false)
          pto.partner_pto_requests.update_all(balance_deducted: false)
        end

        pto.update!(status: kwargs[:status])
      else
        failed_list(kwargs[:user_email], pto.errors.messages.to_s, get_profile_link(kwargs[:user_id]), kwargs[:pto_request_data],
                    kwargs[:index])
      end
    end

    def check_failing_validations(pto_request_errors = '')
      return pto_request_errors if check_req_variables_presence?

      return 'Begin Date and End Date are required' unless @begin_date && @end_date
      return 'Invalid status' unless @status && status_valid?
      return 'User not found' unless @user
      return 'PTO Policy not found' unless @pto_policy
      return 'PTO Policy not assigned to user' unless @assigned_pto_policy
      return 'Balance hours cannot be 0' if @balance_hours.zero?
    end

    def check_req_variables_presence?
      @user && @begin_date && @end_date && @assigned_pto_policy && status_valid? && !@balance_hours.zero?
    end

    def status_valid?
      list = %w[approved pending cancelled]
      list.push('denied') if @pto_policy&.manager_approval
      list.include?(@status)
    end

    def format_date(date)
      Date.strptime(date, company.get_date_regex)
    end

    def get_profile_link(user_id)
      "https://#{company.domain}/#/profile/#{user_id}" if user_id
    end

    def failed_list(email, error, profile_link = '', row, index)
      add_user_error_to_row(row, "Row - #{index} - #{error}")
      @failed_rows << { name: email, link: profile_link, error: error }
    end

    def helper_service
      ImportUsersData::Helper.new
    end
  end
end
