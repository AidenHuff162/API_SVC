module CustomTables
  class FetchCustomTableColumns

    attr_reader :company, :custom_table

    def initialize company, custom_table
      @company = company
      @custom_table = custom_table
      @response = {}
      @response[:custom_fields] = nil
      @response[:preference_fields] = nil
    end

    def perform
      @response[:custom_fields] = custom_fields
      @response[:preference_fields] = preference_fields if @custom_table.custom_table_property == "role_information" || @custom_table.custom_table_property == "employment_status"
      @response
    end

    private

    def custom_fields
      ActiveModelSerializers::SerializableResource.new(@custom_table.custom_fields, each_serializer: CustomFieldSerializer::BasicWithOptions, omit_user: true)
    end

    def preference_fields
      @company.prefrences["default_fields"].map { |f| f if is_table_property_field?(f) }.compact
    end

    def is_table_property_field? field
      field["custom_table_property"] == @custom_table.custom_table_property && !['td', 'tt', 'ltw', 'efr'].include?(field["id"])
    end

  end
end