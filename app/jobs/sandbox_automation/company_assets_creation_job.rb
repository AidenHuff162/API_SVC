class SandboxAutomation::CompanyAssetsCreationJob
  include Sidekiq::Worker
  sidekiq_options :queue => :copy_assets, :retry => false, :backtrace => true

  def perform params
    SandboxAutomation::CompanyAssetsService.new(params).perform
  end
end
