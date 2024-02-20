class HrisIntegrationsService::Bamboo::Zapier::ManageBambooTabularData < HrisIntegrationsService::Bamboo::ManageBambooTabularData
  attr_reader :compensation_custom_fields
  
  def initialize(user)
    super(user)
    @compensation_custom_fields = {
      'start date' => 'startDate',
      'pay rate' => 'rate',
      'pay type' => 'type',
      'pay schedule' => 'paySchedule',
      'pay per' => 'paidPer',
      'change reason' => 'reason',
      'comment' => 'comment'
    }
  end

  def update_tabular_data
    update_emergency_contact
    update_job_information
    update_employment_status
    update_compensation_table
  end

  def update_selected_tabular_data(field_name)
    super(field_name)
    field_name = field_name.try(:downcase)
    if compensation_custom_fields.include? field_name
      update_compensation_table(true)
    end
  end

  private

  def compensation_params(can_send_current_date)
    startDate = can_send_current_date.present? ? Date.today.to_s : user.start_date.to_s
    rate = user.get_custom_field_value_text(compensation_custom_fields.key('rate'), true)
    if rate.class.to_s == 'Hash'
      rate = "#{rate[:currency_value]} - #{rate[:currency_type]}"
    end
    type = user.get_custom_field_value_text(compensation_custom_fields.key('type'))
    paySchedule = user.get_custom_field_value_text(compensation_custom_fields.key('paySchedule'))
    changeReason = user.get_custom_field_value_text(compensation_custom_fields.key('reason'))
    paidPer = user.get_custom_field_value_text(compensation_custom_fields.key('paidPer'))
    comment = nil

    return "<row>
      <field id='startDate'>#{startDate}</field>
      <field id='rate'>#{rate}</field>
      <field id='type'>#{type}</field>
      <field id='paidPer'>#{paidPer}</field>
      <field id='paySchedule'>#{paySchedule}</field>
      <field id='reason'>#{changeReason}</field>
      <field id='comment'>#{comment}</field>
    </row>"
  end 

  def update_compensation_table(can_send_current_date = false)
    params = compensation_params(can_send_current_date)
    if params.present?
      compensation = HrisIntegrationsService::Bamboo::Compensation.new(user.company)
      compensation.create_or_update("#{user.id}: Create/Update Compensation In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end
end