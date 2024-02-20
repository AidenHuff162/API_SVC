module GoogleCredentialStore
  extend ActiveSupport::Concern
  def read_and_store_google_credentials(credential)
    if self.google_credential.nil?
        logger.info "GCP:: Saving in relation!!"
        GoogleCredential.create(:credentialable => self,:credentials => credential)
    else
        logger.info "GCP:: Updating in relation!!"
        self.google_credential.update(:credentials => credential)
    end
  end
end