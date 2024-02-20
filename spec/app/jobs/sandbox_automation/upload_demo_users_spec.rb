require 'rails_helper'

RSpec.describe SandboxAutomation::UploadDemoUsers, type: :job do 

  before { allow_any_instance_of(SandboxAutomation::UploadDemoUsersService).to receive(:perform) { 'Service Excecuted'}}
  it 'should run service and return Service Excecuted' do
    res = SandboxAutomation::UploadDemoUsers.new.perform(nil)
    expect(res).to eq('Service Excecuted')
  end
end