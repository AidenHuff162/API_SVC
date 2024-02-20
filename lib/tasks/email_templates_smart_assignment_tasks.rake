namespace :email_templates_smart_assignment_tasks do

  task update_meta_field_based_on_LDE_filters: :environment do

    puts "... updating meta field of all the email templates based on their LDE filters ..."

    companies = Company.includes(:email_templates)
    companies.find_each do |company|
      company.email_templates.find_each do |email_template|

        meta = email_template.meta
        meta['location_id'] = meta['location_ids']
        meta.delete('location_ids')
        meta['team_id'] = meta['department_ids']
        meta.delete('department_ids')
        meta['employee_type'] = meta['status_ids']
        meta.delete('status_ids')

        email_template.update_column(:meta, meta)
      end
    end

    puts "... Completed ..."

  end

end

