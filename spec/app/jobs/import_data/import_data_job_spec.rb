require 'rails_helper'

RSpec.describe ImportData::ImportDataJob , type: :job do
  let(:company) { create(:company, enabled_time_off: true) }
  let!(:user) {create(:default_pto_policy, company: company)}
  before do
    allow_any_instance_of(::ImportData::ImportDataJob).to receive(:perform) {'Service Executed'}  
  end
 
  it 'should execute service UploadProfileData' do
    args = { company: company, data: {}, current_user: user, upload_date: Date.today }
    result = ImportData::ImportDataJob.new.perform({}, args)
    expect(result).to eq('Service Executed')
  end
end
