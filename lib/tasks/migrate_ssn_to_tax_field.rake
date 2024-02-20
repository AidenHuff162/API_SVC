# USAGE:
# bundle exec rake migrate_ssn_to_tax_field:migrate_ssn_to_tax_field[company_subdomain]
#
# Expects custom field named "Social Security Number" and "Tax" to exist in company account
namespace :migrate_ssn_to_tax_field do

  task :migrate_ssn_to_tax_field, [:company_subdomain] => :environment do |t, args|
    company = Company.find_by(subdomain: args.company_subdomain)
    if company.present?
      puts "--- Migrating SSN to Tax field for #{company.subdomain}  ---"
      ssn_field = company.custom_fields.find_by(name: "Social Security Number")
      tax_field = company.custom_fields.find_by(name: "Tax")
      return unless ssn_field.present? && tax_field.present?

      company.users.try(:find_each) do |user|
        ssn_value = user.custom_field_values.find_by(custom_field_id: ssn_field.id).try(:value_text)
        next unless ssn_value.present?
        CustomFieldValue.set_custom_field_value(user, nil, "SSN", 'Tax Type', false, tax_field)
        CustomFieldValue.set_custom_field_value(user, nil, ssn_value, 'Tax Value', false, tax_field)
      end
      puts "--- Migration completed ---"
    end
  end

end
