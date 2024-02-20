class OverNightService::ApiKeyExpirationEmails

  def perform
    today = Date.today
    ApiKey.where("last_hit::date = ? ", Date.today - 90.days).where.not(company_id: nil, edited_by_id: nil, name: nil).each do |key|
      begin
        UserMailer.api_key_expiration_warning_email(key.edited_by, :expired, key.name).deliver_now! if key.company.account_state == "active"
      rescue
        next
      end
    end
    ApiKey.where("last_hit::date IN (?) ", [Date.today - 83.days, Date.today - 76.days]).where.not(company_id: nil, edited_by_id: nil, name: nil).each do |key|
      begin
        UserMailer.api_key_expiration_warning_email(key.edited_by, :warning, key.name, key.expires_in).deliver_now! if key.company.account_state == "active"
      rescue
        next
      end
    end
  end
end
