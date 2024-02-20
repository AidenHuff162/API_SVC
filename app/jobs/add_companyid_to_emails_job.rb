class AddCompanyidToEmailsJob < ApplicationJob
  queue_as :email_fix

  def perform
    CompanyEmail.find_in_batches(batch_size: 900) do |emails|
      ActiveRecord::Base.transaction do
        mails = emails.select{|x| x.company_id.blank?  }
        mails.compact.try(:each) do |email|
          company_id = User.where('email in (?) OR personal_email in (?)',  email.to, email.to).first.try(:company_id)
          company_id = Workspace.where(associated_email: email.to).first.try(:company_id) if company_id.nil?
          email.update(company_id: company_id ) if company_id.present? && Company.find_by(id: company_id).present?
        end
      end
    end
  end

end