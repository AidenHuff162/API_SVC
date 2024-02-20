class CollectiveEmailsCollection < BaseCollection
  private

  def relation
    @relation ||= UserEmail.all.includes(user: :profile_image)
  end

  def ensure_filters
    company_users_filter
    read_filter if params[:tab] == 'read'
    read_tab_date_range_filter
    sent_filter if params[:tab] == 'sent'
    scheduled_filter if params[:tab] == 'scheduled'
    sent_tab_date_range_filter
    scheduled_tab_date_range_filter
    offboarding_filter if params[:incomplete]
    user_filter if params[:offboarding_scheduled]
    template_type_filter
    sorting_filter
  end

  def read_filter
    filter { |relation| relation.where.not(email_status: UserEmail.statuses[:completed]) }
  end

  def read_tab_date_range_filter
    filter { |relation| relation.where("created_at >= ? AND created_at <= ? ", params[:date_filter][:start_date].to_date.beginning_of_day, params[:date_filter][:end_date].to_date.end_of_day) } if params[:date_filter] && params[:tab] == 'read'
  end

  def sent_filter
    filter { |relation| relation.where(email_status: UserEmail.statuses[:completed])}
  end

  def scheduled_filter
    filter { |relation| relation.where.not(email_status: [UserEmail.statuses[:completed], UserEmail.statuses[:deleted], UserEmail.statuses[:incomplete]])}
  end

  def sent_tab_date_range_filter
    filter { |relation| relation.where("sent_at >= ? AND sent_at <= ? ", params[:date_filter][:start_date].to_date.beginning_of_day, params[:date_filter][:end_date].to_date.end_of_day) } if params[:date_filter] && params[:tab] == 'sent'
  end

  def scheduled_tab_date_range_filter
    filter { |relation| relation.where("invite_at >= ? AND invite_at <= ? ", params[:date_filter][:start_date].to_date.beginning_of_day, params[:date_filter][:end_date].to_date.end_of_day) } if params[:date_filter] && params[:tab] == 'scheduled'
  end

  def template_type_filter
    filter { |relation| relation.where(email_type: params[:email_type])} if params[:email_type]
  end

  def offboarding_filter
    # incomplete status should be during onboarding a user or during offboarding and hard delete on discard
    filter { |relation| relation.where(email_status: UserEmail.statuses[:incomplete]).where(user_id: params[:user_id])} if params[:incomplete]
  end

  def user_filter
    filter { |relation| relation.where(user_id: params[:user_id])}
  end

  def company_users_filter
    return [] unless params[:current_company]
    users = params[:current_company].users
    if params[:current_user].role == 'admin'
      role = params[:current_user].user_role
      users = users.where(location_id: role.location_permission_level) if role.location_permission_level && !role.location_permission_level.include?('all')
      users = users.where(team_id: role.team_permission_level) if role.team_permission_level && !role.team_permission_level.include?('all')
      if role.status_permission_level && !role.status_permission_level.include?('all')
        custom_field_option_ids = CustomFieldOption.where(option: role.status_permission_level).pluck(:id)
        users = users.joins(:custom_field_values).where(custom_field_values: {custom_field_option_id: custom_field_option_ids})
      end
    end

    if params[:team_id]
      users = users.where(team_id: params[:team_id])
    end
    if params[:location_id]
      users = users.where(location_id: params[:location_id])
    end
    if params[:search].present? && params[:search][:value].present?
      pattern = "#{params[:search][:value].to_s.downcase}%"
      users = users.where("TRIM(first_name) ILIKE :pattern OR TRIM(last_name) ILIKE :pattern OR CONCAT_WS(' ', TRIM(first_name), TRIM(last_name)) ILIKE :pattern OR TRIM(preferred_name) ILIKE :pattern OR TRIM(preferred_full_name) ILIKE :pattern OR email LIKE :pattern OR personal_email LIKE :pattern", pattern: pattern)
    end
    if params[:custom_field_option_id]
      users = users.joins(:custom_field_values).where(custom_field_values: {custom_field_option_id: params[:custom_field_option_id]})
    end

    if params[:employment_status_id]
      users = users.joins(:custom_field_values).where(custom_field_values: {custom_field_option_id: params[:employment_status_id]})
    end
    filter { |relation| relation.where(user_id: users.ids)}
  end

  def sorting_filter
    return unless params[:order]

    order = params[:order]["0"]["dir"]
    column = params[:order]["0"]["column"]
    tab = params[:tab]
    if tab == 'scheduled'
      if column == '3'
        order_by_updated_at(order)
      elsif column == '2'
        order_by_template_name(order)
      elsif column == '1'
        order_by_to(order)
      elsif column == '0'
        order_by_invite_at(order)
      end
    elsif tab == 'sent'
      if column == '0'
        order_by_sent_at(order)
      elsif column == '1'
        order_by_to(order)
      elsif column == '2'
        order_by_template_name(order)
      elsif column == '3'
        order_by_status(order)
      end
    else
      if column == '2'
        order_by_sent_at(order)
      elsif column == '0'
        order_by_to(order)
      elsif column == '3'
        order_by_invite_at(order)
      end
    end
  end

  def order_by_sent_at order
    filter { |relation| relation.reorder("sent_at #{order}") }
  end

  def order_by_updated_at order
    filter { |relation| relation.reorder("updated_at #{order}") }
  end

  def order_by_to order
    if params[:incomplete]
      filter { |relation| relation.reorder("created_at #{order}") }
    else
      if params[:current_company].try(:display_name_format) == 4
        filter { |relation| relation.joins(:user).reorder("users.last_name #{order}") }
      elsif params[:current_company].try(:display_name_format) == 2 || params[:current_company].try(:display_name_format) == 3
        filter { |relation| relation.joins(:user).reorder("users.first_name #{order}") }
      else
        filter { |relation| relation.joins(:user).reorder("users.preferred_full_name #{order}") }
      end
    end
  end

  def order_by_invite_at order
    filter { |relation| relation.reorder("invite_at #{order}") }
  end

  def order_by_template_name order
    filter { |relation| relation.reorder("COALESCE(template_name, 'No Template') #{order}") }
  end

  def order_by_status order
    filter { |relation| relation.reorder("COALESCE(activity ->> 'status', 'Not Available') #{order}") }
  end
end
