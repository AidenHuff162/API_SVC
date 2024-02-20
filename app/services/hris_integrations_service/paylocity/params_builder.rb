class HrisIntegrationsService::Paylocity::ParamsBuilder
  attr_reader :parameter_mappings
  delegate :map_change_reason, to: :helper_service

  def initialize(parameter_mappings)
    @parameter_mappings = parameter_mappings
  end

  def build_create_profile_params(data)
    params = build_params(data, 'exclude_in_create'.to_sym, 'parent_hash_path'.to_sym, 'parent_hash'.to_sym).to_json
  end
 
  def build_update_profile_params(data)
    update_params = {} 
    update_params = build_params(data, 'exclude_in_update'.to_sym, 'parent_hash_path'.to_sym, 'parent_hash'.to_sym)
    update_params = map_change_reason(update_params) if Rails.env.staging?
    params = {updateEmployee: update_params}.to_json
  end

  private

  def fetch_value(key, value)
    if key == :status
      [ { hireDate: value} ]
    elsif key == :homeAddress
      data = {}
      data[:address1] = value[:line1][0..39] if value[:line1]
      data[:address2] = value[:line2][0..39] if value[:line2]
      data[:city] = value[:city] if value[:city]

      if value[:state] && value[:country] == "United States"
        state = Country.find_by(name: value[:country]).states.find_by(name: value[:state])
        data[:state] = state ? state.key : value[:state]
      end
      data[:postalCode] = value[:zip] if value[:zip] && value[:country] == "United States"
      data[:emailAddress] = value[:personalEmail] if value[:personalEmail]
      data[:phone] = value[:phone] if value[:phone]
      data[:mobilePhone] = value[:mobilePhone] if value[:mobilePhone]
      [data]
    elsif key == :workAddress
      [{emailAddress: value}]
    elsif key == :jobTitle
      value ? [{ jobTitle: value }] : [{}]
    elsif key == :departmentPosition
      data = {}
      data[:employeeType] = value[:employeeType] if value[:employeeType]
      data[:jobTitle] = value[:jobTitle] if value[:jobTitle]
      data[:supervisorEmployeeId] = value[:supervisorEmployeeId] if value[:supervisorEmployeeId] 
      data[:costCenter1] = value[:costCenter1] if value[:costCenter1]
      data[:costCenter2] = value[:costCenter2] if value[:costCenter2]
      data[:costCenter3] = value[:costCenter3] if value[:costCenter3]
      [data]
    elsif key == :supervisorId
      value[:supervisorEmployeeId] ? { supervisorEmployeeId: value[:supervisorEmployeeId] } : {}
    elsif key == :supervisorEmployeeId
      data = {}
      data[:supervisorEmployeeId] = value[:supervisorEmployeeId] if value[:supervisorEmployeeId]
      data[:reviewerEmployeeId] = value[:reviewerEmployeeId] if value[:reviewerEmployeeId]
      data[:supervisorCompanyNumber] = value[:supervisorCompanyNumber] if value[:supervisorCompanyNumber]
      data[:effectiveDate] = value[:effectiveDate] if value[:effectiveDate]
      data[:changeReason] = value[:changeReason] if value[:changeReason]
      data[:isSupervisorReviewer] = value[:isSupervisorReviewer] if value[:isSupervisorReviewer]
      [data]
    elsif key == :updatePayFrequency
      value ? [{ payFrequency: value }] : [{}] 
    elsif key == :updatePayType
      value ? [{ payType: value[:payType], autoPay: value[:autoPay] }] : [{}] 
    elsif key == :updateBaseRate
      value ? [{ baseRate: value }] : [{}]  
    elsif key == :updateSalary
      value ? [{ salary: value }] : [{}] 
    elsif key == :primaryPayRate
      data = {}
      data[:baseRate] = value[:baseRate] if value[:baseRate]
      data[:salary] = value[:salary] if value[:salary]
      if value[:payType]
        data[:payType] = value[:payType] 
        data[:isAutoPay] = value[:autoPay]
      end
      data[:payFrequency] = value[:payFrequency] if value[:payFrequency]
      data[:effectiveDate] = value[:effectiveDate] if value[:effectiveDate]
      [data]
     elsif key == :update_primary_rate
      value ? [{ effectiveDate: value }] : [{}] 
     elsif key == :update_costCenter1
      value ? [{ costCenter1: value }] : [{}] 
     elsif key == :update_costCenter2
      value ? [{ costCenter2: value }] : [{}] 
     elsif key == :update_costCenter3
      value ? [{ costCenter3: value }] : [{}] 
     elsif key == :update_department_position
      value ? [{ effectiveDate: value }] : [{}] 
    else
      value
    end
  end

  def build_params(data, exclude_in_action, parent_path, parent_hash)
    params = {}
    params.default_proc = -> (h, k) { h[k] = Hash.new(&h.default_proc) }

    data.each do |key, value|
      parameter_mapping = @parameter_mappings[key]
      if parameter_mapping[exclude_in_action].blank?
        parent_hash_path = parameter_mapping[parent_path]
        if parent_hash_path.present?
          build_hash(params, parent_hash_path.split('|'), fetch_value(key, value)) if value.present?
        else
          params[key] = fetch_value(key, value) unless ["",nil].include?(value)
        end
      end
    end

    params
  end

  def build_hash(params, path, value)
    *path, final_key = path
    to_set = path.empty? ? params : params.dig(*path)

    return unless to_set
    previous_value = to_set[final_key]

    if previous_value.class == Hash && value.class == Hash
      value = previous_value.merge!(value)
    elsif previous_value.class == Array && value.class == Array
      value = [previous_value[0].merge!(value[0])]
    end
    
    to_set[final_key] = value
  end

  def helper_service
    ::HrisIntegrationsService::Paylocity::Helper.new
  end
end