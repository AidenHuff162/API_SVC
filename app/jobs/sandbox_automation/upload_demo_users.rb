class SandboxAutomation::UploadDemoUsers
  include Sidekiq::Worker
  sidekiq_options :queue => :copy_assets, :retry => false, :backtrace => true

  def perform params
    SandboxAutomation::UploadDemoUsersService.new(params).perform
  end
end

