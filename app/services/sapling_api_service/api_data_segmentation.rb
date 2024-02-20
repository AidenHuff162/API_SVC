module SaplingApiService
  class ApiDataSegmentation < ApplicationService
    include SaplingApiService::SaplingApiHashes
    attr_reader :company, :user, :api_key_fields

    delegate :prepare_custom_field_hash_data, to: :helper_service

    def initialize(company, api_key_meta_data)
      @company = company
      @user = api_key_meta_data[:user]
      @api_key_fields = api_key_meta_data[:api_key_fields].values.flatten
      @user_data_hash = { guid: user.guid }
    end

    def call
      prepare_api_key_specific_data_hash
    end

    private

    def prepare_api_key_specific_data_hash
      prepare_default_fields_data_hash
      prepare_custom_fields_data_hash
      @user_data_hash
    end

    def prepare_default_fields_data_hash
      api_key_fields.try(:each) do |field_id|
        field_mapping = DEFAULT_FIELDS_MAPPER[field_id.to_sym]
        next unless field_mapping

        default_field_name_hash(field_mapping)
      end
    end

    def default_field_name_hash(field_mapping)
      if field_mapping[:association].blank?
        @user_data_hash[field_mapping[:hash_key]] = user.attributes[field_mapping[:user_attr]]
      else
        user_association = user.send(field_mapping[:association])
        @user_data_hash[field_mapping[:hash_key]] = user_association.blank? ? nil : user_association&.attributes[field_mapping[:user_attr]]
      end
    end

    def prepare_custom_fields_data_hash
      company.custom_fields.where(id: api_key_fields).find_each do |custom_field|
        options = { custom_field: custom_field, user_data_hash: @user_data_hash }
        prepare_custom_field_hash_data(user, options)
      end
    end

    def helper_service
      SaplingApiService::Helper.new
    end
  end
end
