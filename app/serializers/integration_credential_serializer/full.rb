module IntegrationCredentialSerializer
  class Full < ActiveModel::Serializer
    attributes :id, :name, :value, :integration_configuration_id, :dropdown_options, :selected_options

    def value
      if object.integration_configuration.is_encrypted
        object.value.gsub(/.(?=.{4,}$)/,'*') if object.value.present?
      else
        object.value
      end
    end

    def selected_options
      object.selected_options || []
    end
  end
end
