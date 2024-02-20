class LearningAndDevelopmentIntegrationServices::Lessonly::ParamsBuilder
  attr_reader :parameter_mappings

  def initialize(parameter_mappings)
    @parameter_mappings = parameter_mappings
  end

  def build_create_profile_params(data)
    build_params(data, 'exclude_in_create'.to_sym, 'parent_hash_path'.to_sym, 'parent_hash'.to_sym)
  end

  def build_update_profile_params(data)
    build_params(data, 'exclude_in_update'.to_sym, 'parent_hash_path'.to_sym, 'parent_hash'.to_sym)
  end

  def build_params(data, exclude_in_action, parent_path, parent_hash)
    params = {}
    params.default_proc = -> (h, k) { h[k] = Hash.new(&h.default_proc) }

    data.each do |key, value|
      parameter_mapping = @parameter_mappings[key]
      if parameter_mapping[exclude_in_action].blank?
        parent_hash_path = parameter_mapping[parent_path]
        
        if parent_hash_path.blank?
          params[key] = value
        end
      end
    end

    params
  end
end