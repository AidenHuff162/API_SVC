class Invite < ApplicationRecord
  require 'gsuite/manage_account'
  include CalendarEventsCrudOperations, UserStatisticManagement

  has_paper_trail
  acts_as_paranoid
  belongs_to :user_email
  belongs_to :user #Use for resend email and for send invite from people page

  before_validation :ensure_token
  validates_format_of :description, with: Regexp.new(AvoidHtml::HTML_REGEXP, Regexp::MULTILINE), allow_nil: true

  after_commit :set_up_gsuite_account, on: :create, if: :create_gsuit_account?
  after_commit :set_up_adfs_account, on: :create, if: :create_adfs_account?
  after_commit :set_user_current_stage_and_create_events, on: :create

  has_many :attachments, as: :entity, dependent: :destroy,
                        class_name: 'UploadedFile::Attachment'



  def set_up_gsuite_account
    gs_obj = Gsuite::ManageAccount.new
    company = self.user.company
    user = self.user
    gsuite_info_object = company.get_gsuite_account_info
    response  = gs_obj.create_gsuite_account(user, gsuite_info_object, company)
    self.errors.add(:base, "Gsuite Error: #{response[:response_error]}") if response[:response_error].present?
  end

  def self.resend_invitation_email(user_id, current_company)
    begin
      if current_company
        user = current_company.users.find_by_id(user_id)
        email = user.get_invite_email_address if user.present?
        return {title: I18n.t("email_notifications.personal_email_not_found")} unless email.present?
        Interactions::Users::SendInvite.new(user.id, true, true).perform
        return {title: I18n.t("email_notifications.resent_invite", email: email)}
      end
    rescue
      return {title: I18n.t("email_notifications.resent_invite_failed", email: email)}
    end
  end

  def ensure_token
    unless self.token
      enc = nil
      loop do
        raw, enc = Devise.token_generator.generate(self.class, :token)
        break unless Invite.where(token: enc).exists? #To avoid rollback due to unique constraint on index_invites_on_token
      end
      self.token = enc
    end
  end

  private

  def set_user_current_stage_and_create_events
    user = self.user || self.user_email.user
    if user.present? && user.incomplete?
      user.invite!
      user.save
      user.pending_hire.destroy! if user.pending_hire
    elsif user.present? && user.departed?
      user.invite!
      user.pending_hire.destroy! if user.pending_hire && user.pending_hire.duplication_type.present?
      user.rehire!
      user.save
    end
  end

  def self.delete_scheduled_email(job_id, user)
    if user
      History.delete_scheduled_email(user.histories.find_by(job_id: job_id), false)
    end
  end

  def create_gsuit_account?
    begin
      user = self&.user
      user.present? && user.email.present? && user.provision_gsuite && !user.google_account_credentials_sent && user.company.gsuite_credentials_present_for_company && user.gsuite_initial_password.nil?
    rescue Exception => e
      logger.info e.inspect
    end
  end

  def create_adfs_account?
    begin
      user = self&.user
      user.present? && user.email.present? && user.provision_gsuite && !user.active_directory_object_id && user.company.can_provision_adfs? && user.active_directory_initial_password.nil?
    rescue Exception => e
      logger.info e.inspect
    end
  end

  def set_up_adfs_account
    ::SsoIntegrationsService::ActiveDirectory::ManageSaplingProfileInActiveDirectory.new(self&.user).perform('create_and_update')
  end
end
