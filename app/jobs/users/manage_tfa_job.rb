module Users
  class ManageTfaJob < ApplicationJob

    def perform(company_id, user_id = nil, can_update_all = true)      
      company = Company.find_by_id(company_id)
      return unless company.present?

      if can_update_all.present?
        manage_users(company)
      else
        manage_user(company, user_id)
      end
    end

    private

    def manage_users(company)
      users = company.users.where(super_user: false)

      if company.otp_required_for_login?
        users.find_each do |user|
          user.otp_required_for_login = true
          user.show_qr_code = true
          user.otp_secret = User.generate_otp_secret
          user.save!(validate: false)
        end
      else
        users.update_all(otp_required_for_login: false, show_qr_code: false)
      end
    end

    def manage_user(company, user_id)
      user = company.users.find_by_id(user_id)
      return unless user.present?
      
      user.show_qr_code = true
      user.otp_required_for_login = true
      user.otp_secret = User.generate_otp_secret
      user.save!(validate: false)
    end
  end
end