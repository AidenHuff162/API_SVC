class HrisIntegrationsService::Namely::ManageNamelyProfileInSapling
  attr_reader :company, :integration, :namely, :groups
  delegate :create_loggings, :fetch_integration, :is_integration_valid?, :is_user_exists?, :is_user_updated?,
   :establish_connection, :get_namely_profiles, :get_namely_groups, :log_it, to: :helper_service

  def initialize(company)
    @company = company
    @integration = fetch_integration(@company)
    @namely = establish_connection(@integration)
    @groups = get_namely_groups(@integration)
  end

  def perform
    @integration.in_progress!

    unless is_integration_valid?(@integration)
      @integration.failed!
      create_loggings(@company, 'Namely', 404, "Namely credentials missing - Update from Namely")
      return
    end

    execute
    @integration.succeed!
    @integration.update_column(:synced_at, DateTime.now)
  end

  private
  
  def update_profile(profile)
    ::HrisIntegrationsService::Namely::UpdateNamelyProfileInSapling.new(@company, @integration, @namely, @groups, profile).update
  end

  def create_profile(profile)
    ::HrisIntegrationsService::Namely::CreateNamelyProfileInSapling.new(@company, @integration, @namely, @groups, profile).create
  end

  def delete_profile(profile)
    ::HrisIntegrationsService::Namely::DeleteNamelyProfileInSapling.new(@company, profile).delete
  end

  def manage_namely_user
    begin
      page = 1
      profiles = get_namely_profiles(page, @integration)
      is_profiles_exists = profiles['profiles'].any? rescue false
      
      while(is_profiles_exists)      
        profiles['profiles'].each do |profile|
          user_status = profile['user_status'] rescue nil
          if user_status.present? && user_status.eql?('active')
            if !is_user_exists?(profile['id'], @company)
              create_profile(profile)
            elsif is_user_exists?(profile['id'], @company) && !is_user_updated?(profile['id'], profile['updated_at'], @company)
              update_profile(profile)
            end
          elsif user_status.present? && user_status.eql?('inactive')
            delete_profile(profile)
          end
        end
        page += 1
        profiles = get_namely_profiles(page, @integration)
        is_profiles_exists = profiles['profiles'].any?
      end
    rescue Exception => exception
      log_it("Fetch user in Sapling from Namely - Failure", {request: "GET Profile"}, {result: exception.message}, 500, @company)
    end
  end

  def execute
    manage_namely_user
  end

  def helper_service
    HrisIntegrationsService::Namely::Helper.new
  end
end
