namespace :update_pto_employee_status do
  task employee_status: :environment do
    Company.all.each do |company|
      cf = company.custom_fields.where(field_type: 13).take
       company.pto_policies.each do |pto|
        employee_status = pto.filter_policy_by['employee_status']
        next if employee_status.include?('all')
        ids = []
        employee_status.each do |option|
          cf_option = cf.custom_field_options.find_by_option(option)
          ids << cf_option.id if cf_option.present?
        end
        filter = pto.filter_policy_by
        filter['employee_status'] = ids
        pto.update_column(:filter_policy_by, filter)
      end
    end
  end
end