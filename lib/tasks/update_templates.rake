namespace :templates do

  desc "Add set onboard cta for existing templates"
  task update_templates: :environment do
    email_templates = EmailTemplate.all()
    email_templates.each do |template|
      set_cta = false
      set_cta = true if template.email_type == "invitation"
      send_to = "company"
      send_to = "personal" if template.email_type == "invitation"
      send_to = "both" if template.email_type == "offboarding"
      template.update(schedule_options: {"due"=> template.schedule_options['due'], "date" => template.schedule_options['date'], "time" => template.schedule_options['time'], "duration"=> template.schedule_options['duration'], "send_email"=>template.schedule_options['send_email'], "relative_key"=>template.schedule_options['relative_key'], "duration_type"=>template.schedule_options['duration_type'], "to"=>send_to, "from"=>template.schedule_options['from'], "set_onboard_cta" => set_cta})
    end
  puts "Task completed"
  end

  desc "Add time_zone for existing templates"
  task update_templates_for_timezone: :environment do
    companies = Company.all
    companies.find_each do |company|
      if company
        templates = company.email_templates.where(is_temporary: false)
        templates.find_each do |template|
          if template && template.schedule_options["send_email"].present? && template.schedule_options["send_email"] == 2
            time = "12:00 am"
            if template.schedule_options['time'].present?
              time = template.schedule_options['time']
            end
            time_zone = company.time_zone.present? ? company.time_zone : "Pacific Time (US & Canada)"
            if template.schedule_options['time_zone'].present?
              time_zone = template.schedule_options['time_zone']
            end
            template.update(schedule_options: {"due"=> template.schedule_options['due'], "date" => template.schedule_options['date'], "time" => time, "time_zone" => time_zone, "duration"=> template.schedule_options['duration'], "send_email"=>template.schedule_options['send_email'], "relative_key"=>template.schedule_options['relative_key'], "duration_type"=>template.schedule_options['duration_type'], "to"=>template.schedule_options['to'], "from"=>template.schedule_options['from'], "set_onboard_cta"=>template.schedule_options['set_onboard_cta']})
          end
        end
      end
    end
    puts "Task completed"
  end

end
