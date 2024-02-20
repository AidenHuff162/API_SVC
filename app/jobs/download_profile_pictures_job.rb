class DownloadProfilePicturesJob < ApplicationJob
  def perform(company_id, admin_email)
    return unless company_id.present? && admin_email.present?

    Interactions::Users::DownloadProfilePictures.new(company_id, admin_email).perform
  end
end