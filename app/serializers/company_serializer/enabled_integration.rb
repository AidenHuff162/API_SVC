module CompanySerializer
  class EnabledIntegration < ActiveModel::Serializer
    attributes :integration_names

    def integration_names
      exclude_integrations = ['learn_upon', 'lessonly', 'gusto', 'lattice', 'paychex', 'deputy', 'fifteen_five', 'peakon', 'trinet', 'paylocity', 'namely', nil]
      (object.integrations.enabled(exclude_integrations).pluck(:api_name) | object.integration_instances.enabled.pluck(:api_identifier)).uniq
    end
  end
end

