require 'rails_helper'

RSpec.describe Users::RemoveAccessJob, type: :job do

	let!(:company) { create(:company, subdomain: 'foo') }
  let!(:user) { create(:user, company: company) }

	it 'should run service and return true' do
    Users::RemoveAccessJob.new.perform(user.id, Time.now)
    expect(user.offboard_user).to eq(true)
  end

  it 'should run service and return true' do
    Users::RemoveAccessJob.new.perform(user.id, (Time.now + 5000))
    expect(user.offboard_user).to eq(true)
  end

  it 'should run service and return true' do
    Users::RemoveAccessJob.new.perform(user.id, 'abc')
    expect(user.offboard_user).to eq(true)
  end
end