class HrisIntegrationsService::Trinet::ParamsBuilder
  attr_reader :parameter_mappings

  def initialize(parameter_mappings)
    @parameter_mappings = parameter_mappings
  end

  def build_create_profile_params(data)
    params = build_params(data, 'exclude_in_create'.to_sym, 'parent_hash_path'.to_sym, 'parent_hash'.to_sym)
  end

  def build_update_profile_params(data)
  	params = build_params(data, 'exclude_in_update'.to_sym, 'parent_hash_path'.to_sym, 'parent_hash'.to_sym)
  end

  def build_hash(params, path, value)
    *path, final_key = path
    to_set = path.empty? ? params : params.dig(*path)

    return unless to_set
    previous_value = to_set[final_key]

    if previous_value.class == Hash && value.class == Hash
      value = previous_value.merge!(value)
    elsif previous_value.class == Array && value.class == Array
      value = previous_value.concat(value)
    end
    
    to_set[final_key] = value
  end

  def fetch_value(parameter_mapping, key, value, parent_hash)
    if ['biographicalInfo', 'name', 'employmentInfo', 'payInfo', 'timeOffAndBenefits', 'job_reclassification', 'personal', 'name'].include?(parameter_mapping[parent_hash]) 
      { "#{key}": value }
    elsif parameter_mapping[parent_hash] == 'homeContact' 
      value
    end
  end

  def set_default_params_values params
    params["approvalStatus"] = "I"
    params["employmentInfo"]["deptSplit"] = []
    # params["payInfo"] = {}
    # params["timeOffAndBenefits"]["benefitClass"] = {}
    params["timeOffAndBenefits"]["leavePlanCodes"] = {}
    params["employmentInfo"]["deptSplitFlag"] = ""
    params
  end

  def build_params(data, exclude_in_action, parent_path, parent_hash)
    params = {}
    params.default_proc = -> (h, k) { h[k] = Hash.new(&h.default_proc) }

    data.each do |key, value|
      parameter_mapping = @parameter_mappings[key]
      if parameter_mapping[exclude_in_action].blank?
        parent_hash_path = parameter_mapping[parent_path]
        if parent_hash_path.present?
          build_hash(params, parent_hash_path.split('|'), fetch_value(parameter_mapping, key, value, parent_hash))
        else
          params[key] = value
        end
      end
    end

    set_default_params_values(params) if exclude_in_action == :exclude_in_create
    params
  end
end