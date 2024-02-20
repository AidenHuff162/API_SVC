namespace :webhook_tokens do
  task generate_companies_initial_token: :environment do
    Company.where(encrypted_webhook_token: nil).find_each do |company|
      company.revoke_token
    end
  end
end
