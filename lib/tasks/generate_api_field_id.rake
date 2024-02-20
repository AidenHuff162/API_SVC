namespace :generate_api_field_id do
  task create_custom_field_api_id: :environment do |t, args|

    Company.all.find_each do |company|
      custom_fields = company.custom_fields

      custom_fields.find_each do |custom_field|
        field_id = nil
        puts "Field Name: #{custom_field.name}"
        field_id = "PFID#{rand(1_000_000_000..9_999_999_999)}#{custom_field.id}"
        puts "API Field ID: #{field_id}"
        custom_field.update_column(:api_field_id, field_id) if field_id.present?
        puts "--------------------------------"
      end
    end
  end

  task create_prefrences_field_api_id: :environment do |company|
    Company.all.find_each do |company|
      prefrences = company.prefrences
      puts prefrences.inspect

      prefrences['default_fields'].each do |prefrence|
        prefrence['api_field_id'] = prefrence['name'].downcase.parameterize.underscore
      end
      puts prefrences.inspect
      puts "---------------------------"
      company.update_column(:prefrences, prefrences)
    end
  end
end
