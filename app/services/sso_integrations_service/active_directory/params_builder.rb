class SsoIntegrationsService::ActiveDirectory::ParamsBuilder
  attr_reader :parameter_mappings

  def initialize(parameter_mappings)
    @parameter_mappings = parameter_mappings
  end

  def build_create_profile_params(data)
    params = build_params(data, 'exclude_in_create'.to_sym)
    params.merge!({ passwordProfile: { forceChangePasswordNextSignIn: true, password: SecurePassword.generate(15)}})
  end

  def build_update_profile_params(data)
    params = build_params(data, 'exclude_in_update'.to_sym)
  end

  private

  def build_hash(params, path, value)
    *path, final_key = path
    to_set = path.empty? ? params : params.dig(*path)

    return unless to_set
    to_set[final_key] = value
  end

  def fetch_value(parameter_mapping, key, value)
    if ['string_array'].include?(parameter_mapping[:ad_type])
      [value]
    else
      value
    end
  end

  def build_params(data, exclude_in_action)
    params = {}
    params.default_proc = -> (h, k) { h[k] = Hash.new(&h.default_proc) }

    data.each do |key, value|
      parameter_mapping = @parameter_mappings[key]

      if parameter_mapping[exclude_in_action].blank?
        params[key] = fetch_value(parameter_mapping, key, value)
      end
    end

    params
  end
end
