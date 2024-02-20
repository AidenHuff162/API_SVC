class IntegrationsService::ManageIntegrationCustomTables
  include CustomTableSnapshots

  attr_reader :company, :integration_type, :integration_name

  def initialize(company, integration_type = nil, integration_name=nil)
    @company = company
    @integration_type = integration_type
    @integration_name = integration_name
  end

  def manage_role_information_custom_table(user, params)
    role_information = fetch_custom_table(CustomTable.custom_table_properties[:role_information])
    return unless role_information.present? && role_information.is_approval_required?.blank?

    build_ctus(user, role_information, params, 'role_information')
  end

  def manage_employment_status_custom_table(user, params)
    employment_status = fetch_custom_table(CustomTable.custom_table_properties[:employment_status])
    return unless employment_status.present? && employment_status.is_approval_required?.blank?

    build_ctus(user, employment_status, params, 'employment_status')
  end

  def manage_compensation_custom_table(user, params)
    compensation = fetch_custom_table(CustomTable.custom_table_properties[:compensation])
    return unless compensation.present? && compensation.is_approval_required?.blank?

    build_ctus(user, compensation, params, 'compensation')
  end

  def manage_terminated_employment_status_table_snapshot(user, terminated_params = nil, worker_hire_params = nil)
    employment_status = fetch_custom_table(CustomTable.custom_table_properties[:employment_status])
    return unless employment_status.present? && employment_status.is_approval_required?.blank?

    prefrence_fields = fetch_custom_table_preference_fields('employment_status')
    custom_fields = fetch_custom_table_custom_fields(employment_status)
    
    if terminated_params.present?
      termination_date = terminated_params[:termination_date]
      params = { user: {state: 'inactive'}, custom_field: { effective_date: termination_date } }
      custom_snapshot_params = build_custom_snapshot_params(user, employment_status, params, prefrence_fields, custom_fields, termination_date&.to_date)
      terminated_params.delete(:termination_date)
      return if is_ctus_updated?(user, employment_status, custom_snapshot_params, terminated_params)
      
      if can_create_snapshot?(custom_snapshot_params)
        CustomTableUserSnapshot.get_future_termination_based_snapshots(user.id, terminated_params[:last_day_worked]).destroy_all
        CustomTableUserSnapshot.del_future_based_termination_snapshots(user.id, Date.today).destroy_all

        params = { custom_table_id: employment_status.id, state: 'queue', effective_date: params[:custom_field][:effective_date].to_date.strftime('%B %d, %Y'), 
          integration_type: integration_type, terminate_job_execution: true, custom_snapshots_attributes: custom_snapshot_params, is_terminated: true,
          terminated_data: terminated_params }
        ctus = user.custom_table_user_snapshots.create!(params)
        ctus.reload
        
        if ctus.applied?
          user.update_column(:remove_access_timing, 'remove_immediately') if terminated_params[:last_day_worked].to_date < Date.today
          ::CustomTables::AssignCustomFieldValue.new.assign_values_to_user(ctus, should_send_to_integration?)
        end
        user.reload
        
        if ctus.applied? || ctus.queue?
          user.update!(termination_date: terminated_params[:last_day_worked], last_day_worked: terminated_params[:last_day_worked])
          user.offboarding! if terminated_params[:last_day_worked].to_date > Date.today
        end
      end
    end
  end

  def fetch_custom_table(custom_table_property)
    return unless company.is_using_custom_table?
    company.custom_tables.find_by(custom_table_property: custom_table_property)
  end

  private

  def build_ctus(user, custom_table, params, custom_table_property)
    prefrence_fields = fetch_custom_table_preference_fields(custom_table_property)
    custom_fields = fetch_custom_table_custom_fields(custom_table)
    
    create_custom_table_user_snapshot(user, custom_table, 
      build_custom_snapshot_params(user, custom_table, params, prefrence_fields, custom_fields))
  end

  def build_custom_snapshot_params(user, custom_table, params, prefrence_fields, custom_fields, termination_date=nil)
    applied_custom_snapshot = termination_date_custom_snapshot(user, custom_table, termination_date)
    applied_custom_snapshot = fetch_applied_custom_snapshot(user, custom_table) if applied_custom_snapshot.nil?
    
    if applied_custom_snapshot.blank?
      return build_initial_custom_snapshot_params(params, prefrence_fields, custom_fields)
    else
      return build_latest_custom_snapshot_params(user, params, prefrence_fields, custom_fields, 
        applied_custom_snapshot)
    end
  end

  def build_initial_custom_snapshot_params(params, prefrence_fields, custom_fields)
    custom_snapshot_params = build_initial_preference_field_snapshot_params(prefrence_fields, params)
    custom_snapshot_params.concat(build_initial_custom_field_snapshot_params(custom_fields, params))
  end

  def build_initial_preference_field_snapshot_params(prefrence_fields, params)
    custom_snapshot_params = []

    prefrence_fields.try(:each) do |prefrence_field|
      if ['tt', 'efr', 'ltw', 'td'].exclude?(prefrence_field['id'])
        custom_snapshot_param = { preference_field_id: prefrence_field['id'] }
        if prefrence_field['id'] == 'man' && params[:user].key?(:manager_id) 
          custom_snapshot_param[:custom_field_value] = params[:user][:manager_id]
        elsif prefrence_field['id'] == 'dpt' && params[:user].key?(:team_id)
          custom_snapshot_param[:custom_field_value] = params[:user][:team_id]
        elsif prefrence_field['id'] == 'loc' && params[:user].key?(:location_id)
          custom_snapshot_param[:custom_field_value] = params[:user][:location_id]
        elsif prefrence_field['id'] == 'jt' && params[:user].key?(:title)
          custom_snapshot_param[:custom_field_value] = params[:user][:title]
        elsif prefrence_field['id'] == 'st' && params[:user].key?(:state)
          custom_snapshot_param[:custom_field_value] = params[:user][:state]
        else
          custom_snapshot_param[:custom_field_value] = nil
        end
        custom_snapshot_params.push(custom_snapshot_param)
      end
    end

    custom_snapshot_params
  end

  def build_initial_custom_field_snapshot_params(custom_fields, params)
    custom_snapshot_params = []

    custom_fields.try(:each) do |custom_field|
      custom_snapshot_param = { custom_field_id: custom_field.id }
      custom_field_name = custom_field.name.downcase
      
      if custom_field_name == 'effective date'
        if params[:custom_field].key?(:effective_date).blank?
          custom_snapshot_param[:custom_field_value] = Date.today.strftime('%B %d, %Y')
        else
          custom_snapshot_param[:custom_field_value] = params[:custom_field][:effective_date].to_date.strftime('%B %d, %Y')
        end
      elsif custom_field_name == 'business unit' && params[:custom_field].key?(:business_unit)
        custom_snapshot_param[:custom_field_value] = fetch_custom_field_value(custom_field, params[:custom_field][:business_unit])
      elsif custom_field_name == 'adp company code' && params[:custom_field].key?(:company_code)
        custom_snapshot_param[:custom_field_value] = fetch_custom_field_value(custom_field, params[:custom_field][:company_code])
      elsif custom_field_name == 'employment status' && params[:custom_field].key?(:employment_status) && params[:custom_field][:employment_status] != 'Terminated'
        custom_snapshot_param[:custom_field_value] = fetch_custom_field_value(custom_field, params[:custom_field][:employment_status])
      elsif custom_field_name == 'pay frequency' && params[:custom_field].key?(:pay_frequency) && params[:custom_field][:pay_frequency].present?
        custom_snapshot_param[:custom_field_value] = fetch_custom_field_value(custom_field, params[:custom_field][:pay_frequency])
      elsif custom_field_name == 'rate type' && params[:custom_field].key?(:rate_type) && params[:custom_field][:rate_type].present?
        custom_snapshot_param[:custom_field_value] = fetch_custom_field_value(custom_field, params[:custom_field][:rate_type])
      elsif custom_field_name == 'pay rate' && params[:custom_field].key?(:pay_rate) && params[:custom_field][:pay_rate].present?
        custom_snapshot_param[:custom_field_value] = fetch_custom_field_value(custom_field, params[:custom_field][:pay_rate])
      elsif custom_field_name == 'cost center' && params[:custom_field].key?(:cost_center) && params[:custom_field][:cost_center].present?
        custom_snapshot_param[:custom_field_value] = fetch_custom_field_value(custom_field, params[:custom_field][:cost_center])
      else
        custom_snapshot_param[:custom_field_value] = nil
      end
      custom_snapshot_params.push(custom_snapshot_param)
    end

    custom_snapshot_params
  end

  def build_latest_custom_snapshot_params(user, params, prefrence_fields, custom_fields, applied_custom_snapshot)
    custom_snapshot_params = build_latest_snapshot_params_if_change(user, params, prefrence_fields, custom_fields, applied_custom_snapshot)
  end

  def build_latest_snapshot_params_if_change(user, params, prefrence_fields, custom_fields, applied_custom_snapshot)
    custom_snapshot_params = []
    is_value_changed = false

    prefrence_fields.try(:each) do |prefrence_field|
      if ['tt', 'efr', 'ltw', 'td'].exclude?(prefrence_field['id'])
        custom_snapshot = fetch_custom_snapshot(applied_custom_snapshot, prefrence_field['id'])
        custom_snapshot_param = { preference_field_id: prefrence_field['id'], custom_field_value: custom_snapshot&.custom_field_value }

        if prefrence_field['id'] == 'man' && custom_snapshot_param[:custom_field_value].to_s != params[:user][:manager_id].to_s
          custom_snapshot_param[:custom_field_value] = params[:user][:manager_id]
          is_value_changed = true
        elsif prefrence_field['id'] == 'dpt' && custom_snapshot_param[:custom_field_value].to_s != params[:user][:team_id].to_s
          custom_snapshot_param[:custom_field_value] = params[:user][:team_id]
          is_value_changed = true
        elsif prefrence_field['id'] == 'loc' && custom_snapshot_param[:custom_field_value].to_s != params[:user][:location_id].to_s
          custom_snapshot_param[:custom_field_value] = params[:user][:location_id]
          is_value_changed = true
        elsif prefrence_field['id'] == 'jt' && custom_snapshot_param[:custom_field_value].to_s != params[:user][:title].to_s
          custom_snapshot_param[:custom_field_value] = params[:user][:title]
          is_value_changed = true
        elsif prefrence_field['id'] == 'st' && custom_snapshot_param[:custom_field_value].to_s != params[:user][:state].to_s && ((user.state != params[:user][:state]) || params[:user][:rehired])
          custom_snapshot_param[:custom_field_value] = params[:user][:state]
          is_value_changed = true
        end

        custom_snapshot_params.push(custom_snapshot_param)
      end
    end

    build_latest_custom_field_snapshot_params(params, custom_fields, custom_snapshot_params, is_value_changed, applied_custom_snapshot, user)
  end

  def build_latest_custom_field_snapshot_params(params, custom_fields, custom_snapshot_params, is_value_changed, applied_custom_snapshot, user)
    custom_snapshot_params = custom_snapshot_params

    custom_fields.try(:each) do |custom_field|
      custom_snapshot = fetch_custom_snapshot(applied_custom_snapshot, custom_field.id, true)
      custom_snapshot_param = { custom_field_id: custom_field.id, custom_field_value: custom_snapshot&.custom_field_value }
      custom_field_name = custom_field.name.downcase
      if custom_field_name == 'effective date'
        if params[:custom_field].key?(:effective_date).blank?
          custom_snapshot_param[:custom_field_value] = (integration_name == 'workday' && user.if_pre_start? ? user.start_date : Date.today).strftime('%B %d, %Y')
        else
          # next if integration_name == 'workday' && params[:custom_field][:effective_date] == Date.parse(custom_snapshot_param[:custom_field_value])

          custom_snapshot_param[:custom_field_value] = params[:custom_field][:effective_date].to_date.strftime('%B %d, %Y')
          is_value_changed = true
        end
      elsif custom_field_name == 'business unit' && params[:custom_field][:business_unit].present? && custom_snapshot_param[:custom_field_value].to_s != fetch_custom_field_value(custom_field, params[:custom_field][:business_unit]).to_s
        custom_snapshot_param[:custom_field_value] = fetch_custom_field_value(custom_field, params[:custom_field][:business_unit])
        is_value_changed = true
      
      elsif custom_field_name == 'adp company code' && params[:custom_field][:company_code].present? && custom_snapshot_param[:custom_field_value].to_s != fetch_custom_field_value(custom_field, params[:custom_field][:company_code]).to_s
        custom_snapshot_param[:custom_field_value] = fetch_custom_field_value(custom_field, params[:custom_field][:company_code])
        is_value_changed = true
      
      elsif custom_field_name == 'employment status' && params[:custom_field][:employment_status].present? && custom_snapshot_param[:custom_field_value].to_s != fetch_custom_field_value(custom_field, params[:custom_field][:employment_status]).to_s && params[:custom_field][:employment_status] != 'Terminated'
        custom_snapshot_param[:custom_field_value] = fetch_custom_field_value(custom_field, params[:custom_field][:employment_status])
        is_value_changed = true
      
      elsif custom_field_name == 'pay frequency' && params[:custom_field][:pay_frequency].present? && custom_snapshot_param[:custom_field_value].to_s != fetch_custom_field_value(custom_field, params[:custom_field][:pay_frequency]).to_s
        custom_snapshot_param[:custom_field_value] = fetch_custom_field_value(custom_field, params[:custom_field][:pay_frequency])
        is_value_changed = true
      
      elsif custom_field_name == 'rate type' && params[:custom_field][:rate_type].present? && custom_snapshot_param[:custom_field_value].to_s != fetch_custom_field_value(custom_field, params[:custom_field][:rate_type]).to_s
        custom_snapshot_param[:custom_field_value] = fetch_custom_field_value(custom_field, params[:custom_field][:rate_type])
        is_value_changed = true
      
      elsif custom_field_name == 'pay rate' && params[:custom_field][:pay_rate].present? && fetch_currency_value(custom_snapshot_param[:custom_field_value]).to_s != fetch_custom_field_value(custom_field, params[:custom_field][:pay_rate]).to_s
        custom_snapshot_param[:custom_field_value] = fetch_custom_field_value(custom_field, params[:custom_field][:pay_rate])
        is_value_changed = true
      elsif custom_field_name == 'cost center' && params[:custom_field][:cost_center].present? && custom_snapshot_param[:custom_field_value].to_s != fetch_custom_field_value(custom_field, params[:custom_field][:cost_center]).to_s
        custom_snapshot_param[:custom_field_value] = fetch_custom_field_value(custom_field, params[:custom_field][:cost_center])
        is_value_changed = true
      end

      custom_snapshot_params.push(custom_snapshot_param)
    end

    is_value_changed.present? ? custom_snapshot_params : []
  end

  def fetch_custom_snapshot(applied_custom_snapshot, field_id, is_custom_fields = false)
    is_custom_fields.present? ? applied_custom_snapshot.custom_snapshots.where(custom_field_id: field_id).take : 
      applied_custom_snapshot.custom_snapshots.where(preference_field_id: field_id).take
  end

  def create_custom_table_user_snapshot(user, custom_table, custom_snapshot_params)
    return if is_ctus_updated?(user, custom_table, custom_snapshot_params)

    if can_create_snapshot?(custom_snapshot_params)
      # params = { custom_table_id: custom_table.id, state: 'queue', effective_date: Date.today.strftime("%B %d, %Y"),
      #   integration_type: integration_type, terminate_job_execution: true, custom_snapshots_attributes: custom_snapshot_params }
      params = { custom_table_id: custom_table.id, state: 'queue', integration_type: integration_type,
                 terminate_job_execution: true, custom_snapshots_attributes: custom_snapshot_params,
                 effective_date: get_effective_date(custom_snapshot_params, custom_table) }

      ctus = user.custom_table_user_snapshots.create!(params)
      ::CustomTables::AssignCustomFieldValue.new.assign_values_to_user(ctus, should_send_to_integration?) if ctus.reload.applied?
    end
  end

  def should_send_to_integration?
    ['workday'].exclude?(integration_name)
  end

  def fetch_custom_table_preference_fields(custom_table_property)
    return unless custom_table_property.present?
    company.prefrences['default_fields'].select { |default_field| default_field['custom_table_property'] == custom_table_property }
  end

  def fetch_custom_table_custom_fields(custom_table)
    custom_table.custom_fields
  end

  def termination_date_custom_snapshot(user, custom_table, termination_date)
    return unless termination_date && termination_date > user.company.time.to_date
    
    user.custom_table_user_snapshots.where(custom_table_id: custom_table.id,
                                           state: CustomTableUserSnapshot.states[:queue],
                                           is_applicable: true, 
                                           effective_date: termination_date, 
                                           is_terminated: true).take
  end

  def fetch_applied_custom_snapshot(user, custom_table)
    user.custom_table_user_snapshots.where(custom_table_id: custom_table.id, state: CustomTableUserSnapshot.states[:applied], is_applicable: true).take
  end

  def fetch_custom_field_value(custom_field, option)
    return unless option.present?

    if custom_field.mcq? || custom_field.employment_status?
      return custom_field.custom_field_options.where('option ILIKE ?', option).take.try(:id)
    elsif custom_field.currency?
      return "#{option[:currency_code].to_s}|#{option[:amount_value].to_f}"
    end

    return option
  end

  def can_create_snapshot?(custom_snapshot_params)
    count = 0
    custom_snapshot_params.each do |custom_snapshot_param|
      if custom_snapshot_param[:custom_field_value].nil?.blank?
        count = count + 1
      end
    end
    count > 1
  end

  def fetch_currency_value(value)
    return unless value.present?

    code, currency = value.split('|')
    return "#{code}|#{currency.to_f}"
  end

  def snapshot_to_update(user, custom_table, effective_date)
    return if effective_date.blank?

    params = { state: ['applied', 'queue'], custom_table_id: custom_table.id, effective_date: effective_date }
    user.custom_table_user_snapshots.find_by(params)
  end

  def get_effective_date(custom_snapshot_params, custom_table)
    effective_date_field_id = fetch_custom_table_custom_fields(custom_table).find_by(name: 'Effective Date')&.id
    (custom_snapshot_params.select { |ct| ct[:custom_field_id] == effective_date_field_id }).first&.dig(:custom_field_value)
  end

  def is_ctus_updated?(user, custom_table, custom_snapshot_params, terminated_params=nil)
    return if (ctus = snapshot_to_update(user, custom_table, get_effective_date(custom_snapshot_params, custom_table))).blank?

    custom_snapshot_params.each do |csp|
      # custom_snapshot_params: [{preference_field_id/custom_field_id: val, custom_field_value: val}]
      field_id, field_value = csp.keys
      fetch_custom_snapshot(ctus, csp[field_id], (field_id == :custom_field_id))&.update(custom_field_value: csp[field_value])
    end
    
    ctus.assign_attributes(integration_type: integration_type, edited_by_id: nil) if CustomTableUserSnapshot.integration_types.values.include?(integration_type)

    ctus.update(terminated_data: terminated_params, is_terminated: true, terminate_job_execution: true) if terminated_params.present?
    CustomTables::AssignCustomFieldValue.new.assign_values_to_user(ctus, should_send_to_integration?)
    true
  end

end
