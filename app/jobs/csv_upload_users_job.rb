class CsvUploadUsersJob < ApplicationJob
  queue_as :upload_user_data

  def perform company_id, email, demo, file_url=nil
    company = Company.find_by(id: company_id)
    csv = open(file_url)
    UploadUserInformationService.new(company, csv, email, demo, file_url).perform
    # Clear cache
    company.teams.each do |team|
      Team.expire_people_count team.id
    end
    company.locations.each do |location|
      Location.expire_people_count location.id
    end
    company.update_users_on_algolia
  end
end
