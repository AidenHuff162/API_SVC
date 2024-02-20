module CompanySerializer
  class PreboardAbout < ActiveModel::Serializer
    attributes :id, :prefrences, :integration_type, :default_country, :display_name_format, :adp_zip_validations_feature_flag,
               :national_id_field_feature_flag
  end
end
