class HrisIntegrationsService::Namely::DeleteNamelyProfileInSapling
  attr_reader :company, :profile
  delegate :log_it, to: :helper_service

  def initialize(company, profile)
    @company = company
    @profile = profile
  end

  def delete
    delete_profile
  end

  private

  def delete_profile
    begin
      update_status(@profile)
    rescue Exception => exception
      user_data = {
        state: :inactive,
        current_stage: User.current_stages[:departed],
        termination_date: @profile['termination_date'],
        location_id: nil,
        manager_id:  nil,
        buddy_id: nil,
      }
      user_data.merge!(@profile)

      log_it("Terminate user#{@profile['id']} in Sapling - Failure", {request: 'Terminate user'}, {result: exception.message}, 500, @company)
    end
  end

  def update_status(profile)
    user = @company.users.find_by(namely_id: profile['id'])
    if user && user[:current_stage] != User.current_stages[:departed] && user.state != 'inactive' && !user.is_rehired

      user_data = {
        termination_date: profile['departure_date'],
        location_id: nil,
        manager_id:  nil,
        buddy_id: nil,
      }

      user.offboarded!
      user.calendar_feeds.destroy_all
      user.tasks.update_all(owner_id: nil)
      original_user = user.dup
      user.update!(user_data)
      ::Inbox::UpdateScheduledEmail.new.update_scheduled_user_emails(user, original_user)
      log_it("Terminate user#{@profile['id']} in Sapling - Success", {request: 'Terminate user'}, { result: user_data.inspect }, 200, @company)
    end
  end  

  def helper_service
    ::HrisIntegrationsService::Namely::Helper.new
  end
end
