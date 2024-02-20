class LearningAndDevelopmentIntegrationServices::Kallidus::ParamsBuilder
  attr_reader :parameter_mappings

  def initialize(parameter_mappings)
    @parameter_mappings = parameter_mappings
  end

  def build_create_profile_params(data)
    params = build_params(data, 'exclude_in_create'.to_sym, 'parent_hash_path'.to_sym, 'parent_hash'.to_sym)
    [params]
  end

  def build_update_profile_params(data)
    params = build_params(data, 'exclude_in_update'.to_sym, 'parent_hash_path'.to_sym, 'parent_hash'.to_sym, 'update')
    params
  end

  private

  def build_hash(params, path, value, action = nil)
    *path, final_key = path
    to_set = path.empty? ? params : params.dig(*path)

    return unless to_set

    if action.present? && action == "update"
      previous_value = to_set[final_key].present? ? to_set[final_key].present? : nil
      previous_value.present? ? to_set[final_key].push(value) : to_set[final_key] = [value]
    else
      previous_value = to_set[final_key]
      value = previous_value.merge!(value) if previous_value.class == Hash && value.class == Hash
      to_set[final_key] = value
    end
  end

  def fetch_value(params, parameter_mapping, key, value, parent_hash)
    { "#{key}": value }
  end

  def build_params(data, exclude_in_action, parent_path, parent_hash, action = nil)
    params = {}
    params.default_proc = -> (h, k) { h[k] = Hash.new(&h.default_proc) }
    data.each do |key, value|
      parameter_mapping = @parameter_mappings[key]
      if parameter_mapping[exclude_in_action].blank?
        parent_hash_path = parameter_mapping[parent_path]
        if parent_hash_path.present?
          build_hash(params, parent_hash_path.split('|'), fetch_value(params, parameter_mapping, key, value, parent_hash), action)
        else
          params[key] = value
        end
      end
    end

    params
  end
end
