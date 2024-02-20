task :migrate_customfield_string_to_phonetype => :environment do |task, args|
  ActiveRecord::Base.transaction do
    args.extras.to_a.each do |field_name|

      user_mobile_phone = false
      if field_name == "Mobile Phone Number"
        user_mobile_phone = true
      end

      puts "******************************\n"*3
      puts "******#{field_name}*****"
      puts "******************************\n"*3
      sleep(2)

      Company.all.each do |company|

        if user_mobile_phone
          company_prefrence_field = company.prefrences["default_fields"].select{ |f| f["name"] == "Mobile Phone Number" }.first
          mobile_phone = CustomField.create!(name: "Mobile Phone Number", company_id: company.id, field_type: 8, section: 0, is_default: true, required: company_prefrence_field["enabled"], position: company_prefrence_field["position"])
          country_sub_field = SubCustomField.create!(custom_field_id: mobile_phone.id, name: 'Country', field_type: 'short_text', help_text: 'Country')
          area_sub_field = SubCustomField.create!(custom_field_id: mobile_phone.id, name: 'Area code', field_type: 'short_text', help_text: 'Area code')
          phone_sub_field = SubCustomField.create!(custom_field_id: mobile_phone.id, name: 'Phone', field_type: 'short_text', help_text: 'Phone')
        else
          custom_field = company.custom_fields.where(name: field_name).first
          next unless (custom_field && ['short_text', 'long_text'].include?(custom_field.field_type))

          country_sub_field = custom_field.sub_custom_fields.create!(name: 'Country',field_type: "short_text", help_text: 'Country')
          area_sub_field = custom_field.sub_custom_fields.create!(name: 'Area code',field_type: "short_text", help_text: 'Area code')
          phone_sub_field = custom_field.sub_custom_fields.create!(name: 'Phone',field_type: "short_text", help_text: 'Phone')
        end

        puts "\n**\n**\n**\n**\n**\n**\n**\n**\n**\n**\n**\n**\n**\nCompany- #{company.id} - #{company.name}"
        sleep(2)

        company.users.find_each do |user|
          if user_mobile_phone
            old_value = user.phone_number
          else
            old_value = user.get_custom_field_value_text(field_name)
          end

          next if old_value.blank?
          phone_hash = CustomField.parse_phone_string_to_hash(old_value) || {}

          puts "\n\nUser id: #{user.id}"
          puts "Old value: #{old_value}"
          puts "converted hash: #{phone_hash}"

          unless phone_hash[:country_alpha3]
            puts "COUNTRY CODE ALPHA3(e.g: USA, PAK etc) required: "
            phone_hash[:country_alpha3] = STDIN.gets.chomp
          end

          if phone_hash[:area_code].blank? || phone_hash[:phone].blank?
            puts "Area CODE required: "
            phone_hash[:area_code] = STDIN.gets.chomp

            puts "PHONE required: "
            phone_hash[:phone] = STDIN.gets.chomp
          end

          user.custom_field_values.create!(sub_custom_field_id: country_sub_field.id, value_text: phone_hash[:country_alpha3])
          user.custom_field_values.create!(sub_custom_field_id: area_sub_field.id, value_text: phone_hash[:area_code])
          user.custom_field_values.create!(sub_custom_field_id: phone_sub_field.id, value_text: phone_hash[:phone])
        end; 0
        if user_mobile_phone
          company.prefrences["default_fields"].delete_if{ |f| f["name"] == "Mobile Phone Number" }
          company.save!
        else
          custom_field.field_type = "phone"
          custom_field.save!
        end
      end; 0
    end; 0
  end
end
