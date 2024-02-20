class Company::ContactUs
  include Sidekiq::Worker

  def perform(name, email, message, user_id, company_id, modal_name, origin)
    user = User.find_by(id: user_id)
    return unless  user.present?
    company = Company.find_by(id: company_id)
    return unless  company.present?
    collection = UsersCollection.new(company_id: company.id, registered: true)
    sandbox_trial_email = (Rails.env.staging? and trial_modal(modal_name, company) and company.subdomain != 'sandboxtest') ? ENV['AE_SAPLING_EMAIL'] : nil
    to_email = Rails.env.production? ? ENV['ACCOUNTS_SAPLING_EMAIL'] : sandbox_trial_email || user.email ||  user.personal_email
    recipients = [[to_email], [ENV['SQUAD_DONUT_SAPLING_EMAIL']]]
    description = "Company Name: #{company.name} <br/>"
    description += "User Name: #{name} <br/> Email: #{email} <br/> Job Title: #{user.title} <br/> Role: #{user.role} <br/> "
    description += "Address: #{user.get_custom_field_value_text('Home Address')} <br/> Team Member Count: #{collection.results.count} <br/>"
    description += "Paywall origin: #{origin}" if origin.present?
    description += "<br/><br/> Message: #{message.html_safe}"
    description += "<br/><br/> Email Context: #{modal_name.titleize}" if trial_modal(modal_name, company)
    UserMailer.contact_us(company.id, recipients, description).deliver_later!
  end

  def trial_modal modal_name, company
    company.limited_sandbox_access && ['quote_modal', 'contact_us_modal', 'expire_modal'].include?(modal_name)
  end
end
