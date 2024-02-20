class BulkRequestInformationJob
  include Sidekiq::Worker
  sidekiq_options :queue => :default, :retry => false, :backtrace => true

  def perform(user_ids, current_user, company_id, profile_field_ids)
    user_ids.try(:each) do |user_id|
      begin
        RequestInformation.create!(company_id: company_id, requester_id: current_user, requested_to_id: user_id, profile_field_ids: profile_field_ids)
      rescue Exception => e
        logger.info "Failed to create bulk request with user id #{user_id}"
        logger.info "Due to Error => #{e}"
      end
    end
  end
end
