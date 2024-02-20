class SandboxAutomation::CopyIndividualAsset
  include Sidekiq::Worker
  sidekiq_options :queue => :copy_assets, :retry => false, :backtrace => true

  def perform params, method
    SandboxAutomation::CompanyAssetsService.new(params).send(method)
  end
end
