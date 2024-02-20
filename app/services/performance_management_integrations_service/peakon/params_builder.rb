class PerformanceManagementIntegrationsService::Peakon::ParamsBuilder
  attr_reader :parameter_mappings

  def initialize(parameter_mappings)
    @parameter_mappings = parameter_mappings
  end

  def build_create_profile_params(data)
    params = build_params(data, 'exclude_in_create'.to_sym, 'parent_hash_path'.to_sym, 'parent_hash'.to_sym)
    params.merge!({schemas: ['urn:ietf:params:scim:schemas:core:2.0:User', 'urn:ietf:params:scim:schemas:extension:peakon:2.0:User']})
  end

  def build_update_profile_params(data)
    params = build_params(data, 'exclude_in_update'.to_sym, 'parent_hash_path'.to_sym, 'parent_hash'.to_sym)
    params.merge!({schemas: ['urn:ietf:params:scim:schemas:core:2.0:User', 'urn:ietf:params:scim:schemas:extension:peakon:2.0:User']})
  end

  private

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
    if ['name'].include?(parameter_mapping[parent_hash]) 
      { "#{key}": value }
    elsif ['peakon_extension'].include?(parameter_mapping[parent_hash])
      { "#{key.to_s.tr('_', ' ').to_sym}": value }
    elsif ['phoneNumbers'].include?(parameter_mapping[parent_hash])
      [ { value: value, type: 'mobile', primary: true } ]
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
          build_hash(params, parent_hash_path.split('|'), fetch_value(parameter_mapping, key, value, parent_hash))
        else
          params[key] = value
        end
      end
    end
    params
  end
end