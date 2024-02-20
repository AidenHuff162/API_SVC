class BulkOnboardingPeterEmailJob
  include Sidekiq::Worker
  sidekiq_options sidekiq_options queue: :default, retry: 0, backtrace: true

  def perform(managers_and_nick)
    #{manager_id: [user_id, user_id]}
    location = nil
    company = nil
    managers_and_nick.keys.each do |manager_id|
      manager = User.find_by(id: manager_id)
      company ||= manager.company
      if manager
        team_page = "https://#{company.app_domain}/#/team/#{manager_id}"
        remaining_count = managers_and_nick[manager_id].length >= 5 ? (managers_and_nick[manager_id].length - 5) : 0
        email_data = {new_team_members: [], new_hire_count: managers_and_nick[manager_id].length,
         remaining_count: remaining_count, team_page_url: team_page,
         receiver_name: manager.first_name, customer_logo: company.logo,
         customer_brand: company.email_color || '#3F1DCB'
        }
        #Get first five new hires information to pass in the email
        first_five_users = manager.all_managed_users.where(id: managers_and_nick[manager_id]).order(first_name: :asc).limit(5)
        first_five_users.each do |user|
          url = "https://#{company.app_domain}/#/profile/#{user.id}"
          location ||= user.location.name
          email_data[:new_team_members].push({member_name: user.display_name, member_title: user.title, location_name: location, url: url})
        end

        email_data[:location_name] = location
        UserMailer.bulk_onboarding_email_for_sarah_or_peter(manager_id, email_data, false).deliver_later!
      end
    end
  end
end