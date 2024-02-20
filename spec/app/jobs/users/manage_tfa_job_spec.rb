require 'rails_helper'

RSpec.describe Users::ManageTfaJob, type: :job do

	let!(:company) { create(:company, subdomain: 'foo') }
  let!(:user) { create(:user, company: company) }

  it 'should run service and return true' do
    res = Users::ManageTfaJob.perform_now(company, user.id)
    expect(res).to eq(1)
  end

  it 'should run service and return true' do
    res = Users::ManageTfaJob.perform_now(company, user.id, nil)
    expect(res).to eq(true)
  end

  it 'should run service and return true' do
    company.update(otp_required_for_login: true)
    res = Users::ManageTfaJob.perform_now(company, user.id)
    expect(res).to eq(nil)
  end
end