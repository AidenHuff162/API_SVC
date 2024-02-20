require 'rails_helper'

RSpec.describe CustomTables::ManageCsvCustomSnapshotsJob, type: :job do 

  before { allow_any_instance_of(CustomTables::AssignCustomFieldValue).to receive(:assign_values_to_user).and_return(true)}

  it 'should run service and return true' do
    res = CustomTables::ManageCsvCustomSnapshotsJob.perform_now(nil)
    expect(res).to eq(true)
  end
end