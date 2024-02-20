class Gsuite::UpdateGoogleGroupsJob
  include Sidekiq::Worker

  def perform
  	UpdateGoogleGroupsService.new.perform
  end
end
