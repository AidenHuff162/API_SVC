class CreateEmploymentStatusJob < ApplicationJob
  queue_as :default

  def perform(company_id=1)
    company = Company.find company_id
    custom_field = CustomField.find_by company_id: 1, field_type: 13

    company.users.each do  |user|
      puts "-----updateing user '#{user.id} - #{user.first_name}'----------"

      update_user(user, custom_field)
    end
  end

  def update_user(user, custom_field)
    case user.read_attribute(:employee_type)
    when 0
      add_value_to_employment_status(custom_field, user.id, "Full Time")
    when 1
      add_value_to_employment_status(custom_field, user.id, "Part Time")
    when 2
      add_value_to_employment_status(custom_field, user.id, "Temporary")
    when 3
      add_value_to_employment_status(custom_field, user.id, "Contract")
    when 4
      add_value_to_employment_status(custom_field, user.id, "Intern")
    when 5
      add_value_to_employment_status(custom_field, user.id, "Contractor")
    when 6
      add_value_to_employment_status(custom_field, user.id, "Internship")
    when 7
      add_value_to_employment_status(custom_field, user.id, "Terminated")
    when 8
      add_value_to_employment_status(custom_field, user.id, "Freelance")
    when 9
      add_value_to_employment_status(custom_field, user.id, "Consultant")
    when 10
      add_value_to_employment_status(custom_field, user.id, "Full Time Permanent")
    when 11
      add_value_to_employment_status(custom_field, user.id, "Probation")
    when 12
      add_value_to_employment_status(custom_field, user.id, "Retail Employee")
    when 13
      add_value_to_employment_status(custom_field, user.id, "Non Employee")
    when 14
      add_value_to_employment_status(custom_field, user.id, "Apprentice")
    when 15
      add_value_to_employment_status(custom_field, user.id, "On Leave")
    when 16
      add_value_to_employment_status(custom_field, user.id, "Pre Employment")
    when 17
      add_value_to_employment_status(custom_field, user.id, "Project Employee")
    when 18
      add_value_to_employment_status(custom_field, user.id, "On Call")
    when 19
      add_value_to_employment_status(custom_field, user.id, "Term Ft W/Benefits")
    when 20
      add_value_to_employment_status(custom_field, user.id, "Pt W/Benefits")
    when 21
      add_value_to_employment_status(custom_field, user.id, "Leave Of Absence")
    when 22
      add_value_to_employment_status(custom_field, user.id, "Temporary/Intern")
    end
  end

  def add_value_to_employment_status(custom_field, user_id, option_name)
    option = CustomFieldOption.get_custom_field_option(custom_field, option_name)
    if option
      CustomFieldValue.create(custom_field_id: custom_field.id, user_id: user_id, custom_field_option_id: option.id)

    else
      option = CustomFieldOption.create(custom_field_id: custom_field.id, option: option_name.titleize, position: custom_field.custom_field_options.count)
      CustomFieldValue.create(custom_field_id: custom_field.id, user_id: user_id, custom_field_option_id: option.id)
    end
  end
end
