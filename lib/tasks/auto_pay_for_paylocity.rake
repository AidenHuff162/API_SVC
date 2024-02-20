namespace :auto_pay_for_paylocity do
  desc 'creating paylocity for companies'

  task create_auto_pay_field: :environment do
    companies = Company.joins(:integration_instances).where("integration_instances.api_identifier = 'paylocity'")
    companies.try(:each) do |company| 
      custom_field = nil
      custom_field = company.custom_fields.find_by(name: 'Auto Pay', field_type: CustomField.field_types[:mcq])
      
      unless custom_field.present?
        custom_table = company.custom_tables.where('custom_tables.custom_table_property = ?', CustomTable.custom_table_properties[:compensation])&.take
        if company.is_using_custom_table && custom_table
          custom_field = company.custom_fields.create!(name: 'Auto Pay', field_type: CustomField.field_types[:mcq], custom_table_id: custom_table&.id, required: false, collect_from: :admin)
        else
          custom_field = company.custom_fields.create!(name: 'Auto Pay', field_type: CustomField.field_types[:mcq], section: CustomField.sections[:private_info], required: false, collect_from: :admin)
        end
      end
      
      if custom_field.present?
        custom_field.custom_field_options.find_or_create_by(option: 'True')
        custom_field.custom_field_options.find_or_create_by(option: 'False')
      end
    end
    puts "Task completed"
  end
end