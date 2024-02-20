require 'rails_helper'

RSpec.describe SandboxAutomation::CompanyAssetsCreationJob, type: :job do 

  before { allow_any_instance_of(SandboxAutomation::CompanyAssetsService).to receive(:perform) { 'Service Excecuted'} }
  it 'should run service and return Service Excecuted' do
    res = SandboxAutomation::CompanyAssetsCreationJob.new.perform(nil)
    expect(res).to eq('Service Excecuted')
  end
end