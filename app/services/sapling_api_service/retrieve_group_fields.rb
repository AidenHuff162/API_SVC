module SaplingApiService
  class RetrieveGroupFields

    def initialize(company)
      @company = company
    end

    def fetch_group_fields(params)
      prepare_group_fields_data_hash(params)
    end

    private

    def prepare_group_fields_data_hash(params)
      custom_params = {sub_tab: "groups", action: "custom_groups", integration_group: true, company_id: @company.id}
      data ={departments:[], locations:[]}
      get_default_group_fields(data)
      get_custom_group_fields(data, custom_params)

      data.merge!(status: 200)
    end

    def get_default_group_fields(data)
      departments = @company.teams.all.order('name ASC')
      locations = @company.locations.all
      departments.each do |department|
        data[:departments].push prepare_hash(department)
      end
      locations.each do |location|
        data[:locations].push prepare_hash(location, true)
      end
    end

    def get_custom_group_fields(data, custom_params)
      custom_group_fields = CustomFieldsCollection.new(custom_params)
      custom_group_fields.results.each do |field|
        data[:"#{field.name}"] = []
        field.custom_field_options.each do |option|
          data[:"#{field.name}"].push  prepare_custom_field_hash(option)
        end
      end
    end

    def prepare_hash(field, is_location = false)
      data = {
        name: field.name,
        description: field.description,
        active: field.active,
        company_id: field.company_id,
        owner_id: field.owner_id,
        users_count: field.users_count,
        adp_wfn_us_code_value: field.adp_wfn_us_code_value,
        namely_group_type: field.namely_group_type,
        namely_group_id: field.namely_group_id,
        adp_wfn_can_code_value: field.adp_wfn_can_code_value
      }
      data.merge!(is_gdpr_imposed: field.is_gdpr_imposed) if is_location

      data
    end

    def prepare_custom_field_hash(field)
      data = {
        name: field.option,
        description: field.description,
        active: field.active,
        namely_group_type: field.namely_group_type,
        namely_group_id: field.namely_group_id,
        owner_id: field.owner_id,
        position: field.position,
        workday_wid: field.workday_wid,
        adp_wfn_us_code_value: field.adp_wfn_us_code_value,
        adp_wfn_can_code_value: field.adp_wfn_can_code_value,
        gsuite_mapping_key: field.gsuite_mapping_key,
        paylocity_group_id: field.paylocity_group_id
      }
    end
  end
end
