class WeeklyTeamDigestEmailService

  def initialize(user, test_user = nil)
    @user = user
    @data = {}
    @company = @user.company
    @account_owner = test_user
  end

  def trigger_digest_email(start_date, end_date)
    @start_date,  @end_date = start_date, end_date
    initialize_time_off_data if @company.enabled_time_off
    initialize_anniversary_and_dob_data
    if @data.present?
      if start_date.month == end_date.month
        @data[:date_range] = "#{start_date.strftime("%B %-d")} - #{end_date.strftime("%-d")}"
      else
        @data[:date_range] = "#{start_date.strftime("%b %-d")} - #{end_date.strftime("%b %-d")}"
      end
      UserMailer.send_team_digest_email(@user, @data, @account_owner).deliver_now!
    end
  end

  def get_team_out_of_office_data(start_date, end_date)
    @start_date,  @end_date = start_date, end_date
    pto_begin = PtoRequest.approved_requests_for_users_with_date_range(start_date, end_date, @user.managed_users_working.ids)
    initialize_pto_user_data(pto_begin, 'starting') if pto_begin.present?
    @data
  end

  private

  def initialize_time_off_data
    pto_begin = PtoRequest.where(user_id: @user.cached_managed_user_ids).where(status: 1).where('DATE(begin_date) >= ?  and DATE(begin_date) <= ?', @start_date, @end_date).includes(:user)
    initialize_pto_user_data(pto_begin, 'starting') if pto_begin.present?

    includes_previous = @start_date - 4.days #use if someone end_date is friday and return on Monday
    pto_returning = PtoRequest.where(user_id: @user.cached_managed_user_ids).where(status: 1).where('DATE(end_date) >= ?  and DATE(end_date) <= ? and DATE(begin_date) < ?', includes_previous, @end_date, @start_date).includes(:user)
    initialize_pto_user_data(pto_returning, 'returning') if pto_returning.present?
  end

  def initialize_pto_user_data pto_requests, type
    out_off_office = []
    pto_requests.each do |request|
      member_data = {}
      member_pto_data = {}
      pto_data = []
      sub_pto_data = {}
      return_date = Pto::GetReturnDayOfUser.new.perform(request, true)
      next if (type == 'returning' && (return_date.nil? ||  !(@start_date..@end_date).include?(return_date.to_date)))
      user = request.user
      
      existing_data = fetch_same_user_pto_data user.id, out_off_office
      if(existing_data.present?)
        member_pto_data[:pto_amount] = request.get_request_length
        member_pto_data[:pto_policy_name] = request.pto_policy.name
        if return_date.present?
          if Date.today.year == return_date.year
            member_pto_data[:pto_return_date] = return_date.strftime("%B %-d")
          else
            member_pto_data[:pto_return_date] = return_date.strftime("%B %-d, %Y")
          end
        end
        member_pto_data[:pto_start_date] = request.begin_date.strftime("%B %-d") if request.begin_date
        data = fetch_same_name_pto_data member_pto_data[:pto_policy_name], existing_data[:pto_data]
        if data.present?
          data[:policies].push(member_pto_data)
        else
          sub_pto_data[:policy] = member_pto_data[:pto_policy_name]
          sub_pto_data[:policies] = [member_pto_data]
          pto_data.push(sub_pto_data)
          existing_data[:pto_data].push(sub_pto_data)
        end
      else
        member_data[:member_id] = user.id
        member_data[:member_name] = user.display_name
        member_data[:member_avatar] = user.picture || "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTkF8Lw_tDKvUUjFCbFmAcDQFqAS2IHXX8ncf1HsqdIzMGW7QjT8g"
        member_data[:member_title] = user.title
        member_data[:member_location] = user.location&.name
        member_pto_data[:pto_amount] = request.get_request_length
        member_pto_data[:pto_policy_name] = request.pto_policy.name
        if return_date.present?
          if Date.today.year == return_date.year
            member_pto_data[:pto_return_date] = return_date.strftime("%B %-d")
          else
            member_pto_data[:pto_return_date] = return_date.strftime("%B %-d, %Y")
          end
        end
        member_pto_data[:pto_start_date] = request.begin_date.strftime("%B %-d") if request.begin_date
        
        sub_pto_data[:policy] = member_pto_data[:pto_policy_name]
        sub_pto_data[:policies] = [member_pto_data]
        pto_data.push(sub_pto_data)
        member_data[:pto_data] = pto_data
        out_off_office.push(member_data)
      end
    end
    @data[:starting_pto_team_members] = out_off_office if !out_off_office.empty? && type == 'starting'
    @data[:returning_pto_team_members] = out_off_office if !out_off_office.empty? && type == 'returning'
  end

  def initialize_anniversary_and_dob_data
    anniversaries_data = []
    bday_data = []
    @user.managed_users.each do |user|
      anniversary = user.get_anniversary_date(@start_date, @end_date) if (@company.calendar_permissions["anniversary"].nil? || @company.calendar_permissions["anniversary"] == true)
      dob = user.get_birthday_date(@start_date, @end_date) if (@company.calendar_permissions["birthday"].nil? || @company.calendar_permissions["birthday"] == true)
      if anniversary.present?
        data = initialize_user_data user, anniversary, 'anniversary'
        anniversaries_data.push(data)
      end
      if dob.present?
        data = initialize_user_data user, dob, 'dob'
        bday_data.push(data)
      end
    end
    @data[:ann_team_members] = anniversaries_data unless anniversaries_data.empty?
    @data[:bday_team_members] = bday_data unless bday_data.empty?
  end

  def initialize_user_data user, value, type
    data = {}
    data[:member_name] = user.display_name
    data[:member_avatar] = user.picture || "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTkF8Lw_tDKvUUjFCbFmAcDQFqAS2IHXX8ncf1HsqdIzMGW7QjT8g"
    data[:member_title] = user.title
    data[:member_location] = user.location&.name
    if type == 'anniversary'
      data[:work_ann_amount] = value[:title]
      data[:work_ann_date] = value[:date]
    else
      data[:bday_date] = value
    end
    data
  end

  def fetch_same_user_pto_data user_id, out_off_office
    if out_off_office.present?
      data = out_off_office.select {|k| k[:member_id] == user_id}
      return data[0] if data.present?
    end
  end

  def fetch_same_name_pto_data key, pto_data
    if pto_data.present?
      data = pto_data.select {|k| k[:policy] == key}
      return data[0] if data.present?
    end
  end

end
