namespace :custom_section do
  
  desc "Update Custom Fields custom_section_id"
  task update_custom_section_id: :environment do
    Company.find_each do |company|
      sections = [ 'profile', 'personal_info', 'private_info', 'additional_fields']
      sections.each do |section|
        company.custom_sections.find_or_create_by(section: CustomSection.sections[section])
      end
      custom_section_ids = company.custom_sections.pluck(:section,:id).to_h
      company.custom_fields.find_each do |cf|
        if cf.section? and !cf.custom_section_id?
          custom_section_id = custom_section_ids[cf.section]
          cf.update_column(:custom_section_id, custom_section_id)
        end
      end
      company.prefrences['default_fields'].each do |pref|
        if !pref['custom_section_id'].present? and pref['profile_setup'] == 'profile_fields'
          pref.merge!({'custom_section_id' => custom_section_ids[pref['section']]})
        end
      end
      prefrences = company.prefrences
      company.update_columns(prefrences: prefrences)
    end
    puts "Task completed"
  end
end
