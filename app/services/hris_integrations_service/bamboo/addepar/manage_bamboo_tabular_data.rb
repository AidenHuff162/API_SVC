class HrisIntegrationsService::Bamboo::Addepar::ManageBambooTabularData < HrisIntegrationsService::Bamboo::ManageBambooTabularData
  attr_reader :level_custom_fields, :immigration_custom_fields, :addepar_employment_status_fields, :bonus_custom_fields, :compensation_custom_fields

  def initialize(user)
    super(user)
    @emergency_custom_fields.merge! ({
      'emergency contact address' => 'address',
      'emergency contact email Address' => 'email'
    })

    @level_custom_fields = {
      'date' => 'customEffectiveDate',
      'level' => 'customCurrentLevel',
      'comp band code' => 'customRadfordCode'
    }

    @immigration_custom_fields = {
      'country of citizenship' => 'customCitizenship',
      'type of visa (if applicable)' => 'customVisaType',
      'visa expiration date (if applicable)' => 'customExpirationDate'
    }

    @employment_status_fields = []
    @addepar_employment_status_fields = [ 'employment status' ]
    @bonus_custom_fields = {
      'bonus amount' => 'customBonusAmount',
      'bonus type' => 'customBonusType',
      'bonus comments' => 'customComments'
    }
    @compensation_custom_fields = {
      'pay rate effective date' => 'startDate',
      'pay rate' => 'rate',
      'pay type' => 'type',
      'pay period' => 'paidPer',
      'pay schedule' => 'paySchedule',
      'flsa code (exempt/non exempt)' => 'exempt'
    }
  end

  def update_tabular_data
    update_emergency_contact
    update_job_information
    update_employment_status
    update_level_table
    update_immigration_table
    update_bonus_table
    update_compensation
  end

  def update_selected_tabular_data(field_name)
    super(field_name)
    if addepar_employment_status_fields.include? field_name.try(:downcase)
      update_employment_status(true)
    elsif level_custom_fields["#{field_name.try(:downcase)}"].present?
      update_level_table(true)
    elsif immigration_custom_fields["#{field_name.try(:downcase)}"].present?
      update_immigration_table
    elsif bonus_custom_fields["#{field_name.try(:downcase)}"].present?
      update_bonus_table(true)
    elsif compensation_custom_fields["#{field_name.try(:downcase)}"].present?
      update_compensation(true)
    end
  end

  def employment_status_params(can_send_current_date)
    if user.employee_type == 'Full Time' || user.employee_type == 'Part Time'
      employmentHistoryStatus = user.employee_type.gsub(' ','-').capitalize rescue nil
    elsif user.employee_type == 'Pre Employment'
      employmentHistoryStatus = user.employee_type.gsub('_',' ').titleize.gsub(' ', '-') rescue nil
    else
      employmentHistoryStatus = user.employee_type.gsub('_',' ').titleize rescue nil
    end
    date = can_send_current_date.present? ? Date.today.to_s : user.start_date.to_s

    params = nil
    if employmentHistoryStatus.present?
      params = "<row>
        <field id='date'>#{date}</field>
        <field id='employmentStatus'>#{employmentHistoryStatus}</field>
      </row>"
    end

    params
  end

  def level_contact_params(can_send_current_date)
    customCurrentLevel = user.get_custom_field_value_text(level_custom_fields.key('customCurrentLevel'))
    customRadfordCode = user.get_custom_field_value_text(level_custom_fields.key('customRadfordCode'))
    date = can_send_current_date.present? ? Date.today.to_s : user.start_date.to_s

    params = nil
    if customCurrentLevel.present? || customRadfordCode.present?
      params = "<row>
        <field id='customEffectiveDate'>#{date}</field>
        <field id='customCurrentLevel'>#{customCurrentLevel}</field>
        <field id='customRadfordCode'>#{customRadfordCode}</field>
      </row>"
    end

    params
  end

  def immigration_contact_params
    customCitizenship = user.get_custom_field_value_text(immigration_custom_fields.key('customCitizenship'))
    customVisaType = user.get_custom_field_value_text(immigration_custom_fields.key('customVisaType'))
    customExpirationDate = user.get_custom_field_value_text(immigration_custom_fields.key('customExpirationDate'))

    params = nil
    if customCitizenship.present? || customVisaType.present? || customExpirationDate.present?
      params = "<row>
        <field id='customCitizenship'>#{customCitizenship}</field>
        <field id='customVisaType'>#{customVisaType}</field>
        <field id='customExpirationDate'>#{customExpirationDate.to_s}</field>
      </row>"
    end

    params
  end

  def bonus_params(can_send_current_date)
    customBonusDate1 = can_send_current_date.present? ? Date.today.to_s : user.start_date.to_s
    customBonusAmount = user.get_custom_field_value_text(bonus_custom_fields.key('customBonusAmount'))
    customBonusType = user.get_custom_field_value_text(bonus_custom_fields.key('customBonusType'))
    customBonusComment = user.get_custom_field_value_text(bonus_custom_fields.key('customComments'))

    params = nil
    if customBonusAmount.present? || customBonusType.present? || customBonusComment.present?
      params = "<row>
        <field id='customDate1'>#{customBonusDate1}</field>
        <field id='customBonusAmount'>#{customBonusAmount}</field>
        <field id='customBonusType'>#{customBonusType}</field>
        <field id='customComments'>#{customBonusComment}</field>
      </row>"
    end

    params
  end

  def compensation_params(can_send_current_date)
    startDate = can_send_current_date.present? ? Date.today.to_s : user.start_date.to_s
    rate = user.get_custom_field_value_text(compensation_custom_fields.key('rate'))
    type = user.get_custom_field_value_text(compensation_custom_fields.key('type'))
    paidPer = user.get_custom_field_value_text(compensation_custom_fields.key('paidPer'))
    paySchedule = user.get_custom_field_value_text(compensation_custom_fields.key('paySchedule'))
    exempt = user.get_custom_field_value_text(compensation_custom_fields.key('exempt'))

    params = nil
    if rate.present? || type.present? || paidPer.present? || paySchedule.present? || exempt.present?
      params = "<row>
        <field id='startDate'>#{startDate}</field>
        <field id='rate'>#{rate}</field>
        <field id='type'>#{type}</field>
        <field id='paidPer'>#{paidPer}</field>
        <field id='paySchedule'>#{paySchedule}</field>
        <field id='exempt'>#{exempt}</field>
      </row>"
    end

    params
  end

  private

  def update_employment_status(can_send_current_date = false)
    params = employment_status_params(can_send_current_date)
    if params.present?
      employment_status = HrisIntegrationsService::Bamboo::EmploymentStatus.new(user.company)
      employment_status.create_or_update("#{user.id}: Create/Update Employment Status In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_level_table(can_send_current_date = false)
    params = level_contact_params(can_send_current_date)
    if params.present?
      level = HrisIntegrationsService::Bamboo::Level.new(user.company)
      level.create_or_update("#{user.id}: Create/Update Custom Level In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_immigration_table
    params = immigration_contact_params
    if params.present?
      immigration = HrisIntegrationsService::Bamboo::Immigration.new(user.company)
      immigration.create_or_update("#{user.id}: Create/Update Immigration In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end

  def update_bonus_table(can_send_current_date = false)
    params = bonus_params(can_send_current_date)
    if params.present?
      bonus = HrisIntegrationsService::Bamboo::Bonus.new(user.company)
      bonus.create_or_update("#{user.id}: Create/Update Bonus In Bamboo (#{user.bamboo_id})", user.bamboo_id, params, 'customBonuses')
    end
  end

  def update_compensation(can_send_current_date = false)
    params = compensation_params(can_send_current_date)
    if params.present?
      compensation = HrisIntegrationsService::Bamboo::Compensation.new(user.company)
      compensation.create_or_update("#{user.id}: Create/Update Compensation In Bamboo (#{user.bamboo_id})", user.bamboo_id, params)
    end
  end
end
