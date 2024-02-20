class ApiKeyExpirationEmailsJob < ApplicationJob

  def perform
    OverNightService::ApiKeyExpirationEmails.new.perform
  end
end
