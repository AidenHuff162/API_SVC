class AdminUser < ApplicationRecord
  role_based_authorizable
  extend Devise::Models
  has_paper_trail
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable

  include AASM

  devise :two_factor_authenticatable, :trackable, :recoverable, :rememberable,
         :otp_secret_encryption_key => ENV['TWO_FACTOR_ENCRYPTION_KEY']

  has_many :active_admin_loggings

  attr_accessor :after_state_change

  after_create :enable_two_factor_authentication
  after_create :send_email_to_admin_user
  after_update :enable_two_factor_authentication, if: Proc.new { |au| au.saved_change_to_state? && au.state == 'active' && !au.after_state_change }
  after_save :update_first_login_as_false, if: Proc.new { |au| au.saved_change_to_sign_in_count? && au.first_login.present? }
  after_save :update_first_login_as_true, if: Proc.new { |au| au.saved_change_to_otp_required_for_login? && au.otp_required_for_login.present? }
  before_create :generate_token_for_authentication

  aasm(:state, column: :state, whiny_transitions: false) do
    state :active, initial: true
    state :inactive

    event :activate do
      transitions from: :inactive, to: :active
    end

    event :deactivate do
      transitions from: :active, to: :inactive
    end
  end

  def setup_two_factor(otp_required_for_login)
    self.otp_required_for_login = otp_required_for_login
    if otp_required_for_login
      self.otp_secret = AdminUser.generate_otp_secret
      self.first_login = true
    end
  end

  def two_fa_status
    self.otp_required_for_login ? 'Enabled' : 'Disabled'
  end

  def enable_two_factor_authentication
    self.otp_required_for_login = true
    self.otp_secret = AdminUser.generate_otp_secret
    self.first_login = true
    self.after_state_change = true
    self.save!
  end

  def update_first_login_as_false
    self.update_column(:first_login, false)
  end

  def update_first_login_as_true
    self.update_column(:first_login, true)
  end

  def send_email_to_admin_user
    UserMailer.admin_user_email(self).deliver_now!
  end

  def generate_token_for_authentication
    encrypted_key = JsonWebToken.encode({email: self.email})
    self.email_verification_token = encrypted_key
  end

end
