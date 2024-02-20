module CustomFieldValueManager
  class StructureFormatter < ApplicationService

    def initialize(custom_field, custom_field_values)
      @custom_field = custom_field
      @custom_field_values = custom_field_values
    end

    def call
      format
    end

    private

    attr_reader :custom_field_values, :custom_field

    def format
      @custom_field_values.map do |custom_field_value|
        format_custom_field_value(custom_field_value)
      end
    end

    # Builds custom field values
    def build_cf_values(field)
      { field_id: field.id,
        field_name: field.name,
        field_type: field.field_type,
        field_value_class: 'CustomFieldValue'
      }
    end

    # Builds sub custom field values
    def build_sub_cf_values(field)
      { field_subfield_id: field.id,
        field_subfield_name: field.name,
        field_subfield_type: field.field_type,
      }
    end

    # Builds custom table values
    def build_ct_values(field)
      {
        field_table_id: field.custom_table_id,
        field_table_name: field.custom_table.name
      }
    end

    # Builds custom field option values
    def build_cf_option_values(custom_field_value)
      custom_field_option = custom_field_value.custom_field_option

      { field_value: custom_field_option&.option,
        field_value_id: custom_field_option&.id,
        field_value_class: 'CustomFieldOption'
      }
    end

    # Builds custom field coworker values
    def build_coworker_values(custom_field_value)
      coworker = custom_field_value.coworker

      {
        field_value: coworker&.display_name,
        field_value_id: coworker&.id,
        field_value_class: "User"
      }
    end

    def format_custom_field_value(custom_field_value)
      value = { is_type_subfield: @custom_field.is_type_subfield?,
                is_type_option_field: @custom_field.is_type_option_field?,
                is_type_coworker: @custom_field.coworker?,
                is_section_custom_table: @custom_field.custom_table.present?,
                field_section: @custom_field.section || @custom_field.custom_table&.name,
                field_value: custom_field_value.value_text }.merge!(build_cf_values(@custom_field))

      value_type_subfield(value, custom_field_value)
      value_type_section_custom_table(value)
      value_type_option_field(value, custom_field_value)
      value_type_coworker(value, custom_field_value)
      value
    end

    def value_type_subfield(value, custom_field_value)
      value.merge!(build_sub_cf_values(custom_field_value.sub_custom_field)) if value[:is_type_subfield]
    end

    def value_type_section_custom_table(value)
      value.merge!(build_ct_values(@custom_field)) if value[:is_section_custom_table]
    end

    def value_type_option_field(value, custom_field_value)
      value.merge!(build_cf_option_values(custom_field_value)) if value[:is_type_option_field]
    end

    def value_type_coworker(value, custom_field_value)
      value.merge!(build_coworker_values(custom_field_value)) if value[:is_type_coworker]
    end
  end
end
