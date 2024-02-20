require 'rails_helper'

RSpec.describe SandboxAutomation::CopyIndividualAsset, type: :job do 
  before { allow_any_instance_of(SandboxAutomation::CompanyAssetsService).to receive(:copy_documents) { 'Service Excecuted'}}
  it 'should run service and return Service Excecuted' do
    res = SandboxAutomation::CopyIndividualAsset.new.perform({}, 'copy_documents')
    expect(res).to eq('Service Excecuted')
  end
end