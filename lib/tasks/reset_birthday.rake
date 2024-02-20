namespace :reset_birthday do

  task :reset => :environment do |t, args|
    puts "================================"
    Company.all.try(:find_each) do |company|
      puts "===============#{company.name}================"
      date_fields = company.custom_fields.where(field_type: 6)
      date_fields.try(:find_each) do |date_field|
        puts "===============#{date_field.name}================"
        custom_values = CustomFieldValue.where(custom_field_id: date_field.id)
        custom_values.try(:find_each) do |custom_value|
          if custom_value.value_text.present?
            puts "------------"
            puts custom_value.value_text
            begin
              custom_value.value_text = custom_value.value_text.to_date.strftime("%Y-%m-%d")
              custom_value.save
              puts custom_value.value_text
            rescue Exception => e
              puts e
            end
            puts "-------------"
          end
        end
        puts "===============#{date_field.name}================"
      end
      puts "===============#{company.name}================"
    end
  end
end
