class UserDocumentConnectionCollection < BaseCollection
  private

  def relation
    @relation ||= UserDocumentConnection.all
  end

  def ensure_filters
    company_filter
    user_current_stage_filter
    user_filter
    document_connection_relation_filter
    exclude_drafts_filter
    status_filter
    team_filter
    location_filter
    employee_type_filter
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id])} if params[:company_id]
  end

  def user_filter
    filter { |relation| relation.where(user_id: params[:user_id])} if params[:user_id]
  end

  def document_connection_relation_filter
    filter { |relation| relation.where(document_connection_relation_id: params[:document_connection_relation_id])} if params[:document_connection_relation_id]
  end

  def exclude_drafts_filter
    filter { |relation| relation.where.not(state: 'draft') } if params[:exclude_drafts]
  end

  def status_filter
    if params[:status]
      if params[:status] == 'completed_docs'
        filter { |relation| relation.where(state: 'completed') }
      elsif params[:status] == 'in_progress_docs'
        filter { |relation| relation.where(state: 'request') }
      end
    end
  end

  def team_filter
    filter do |relation|
      relation.joins(:user).where(users: {team_id: params[:team_id]})
    end if params[:team_id]
  end

  def location_filter
    filter do |relation|
      relation.joins(:user).where(users: {location_id: params[:location_id]})
    end if params[:location_id]
  end

  def employee_type_filter
    if params[:company_id] && params[:employee_type] && params[:employee_type] != 'All Employee Status' && !params[:multiple_custom_groups]
      filter { |relation| relation.joins(:user => {:custom_field_values => [custom_field_option: :custom_field]}).where("custom_fields.company_id = ? AND custom_fields.field_type = ? AND custom_field_options.option IN (?)", params[:company_id], 13, params[:employee_type]) }
    end
  end

  def user_current_stage_filter
    if params[:user_state_filter] && !params[:user_state_filter].eql?('all_users')
      current_stages =  case params[:user_state_filter]
                        when 'onboarding_only'
                          [ User.current_stages[:invited], 
                            User.current_stages[:preboarding], 
                            User.current_stages[:pre_start], 
                            User.current_stages[:first_week], 
                            User.current_stages[:first_month], 
                            User.current_stages[:ramping_up] ]
                        when 'active_only'
                          [ User.current_stages[:registered] ]
                        when 'offboarding_only'
                          [ User.current_stages[:offboarding],
                            User.current_stages[:last_month],
                            User.current_stages[:last_week] ]
                        when 'departed_only'
                          [ User.current_stages[:departed] ]
                        end
      filter { |relation| relation.joins(:user).where(users: { current_stage: current_stages })}
    end
  end
end
