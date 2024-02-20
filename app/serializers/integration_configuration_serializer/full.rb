module IntegrationConfigurationSerializer
  class Full < ActiveModel::Serializer
    attributes :id, :field_name, :field_type, :toggle_context, :toggle_identifier, :category, :dropdown_options, :vendor_domain,
               :width, :help_text, :is_required, :is_visible

    def dropdown_options
      object.dropdown_options.present? && object.dropdown_options.class == String ? JSON.parse(object.dropdown_options) : object.dropdown_options
    end               
  end
end
