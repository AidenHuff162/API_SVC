require 'rails_helper'

RSpec.describe BulkInvitesJob, type: :job do

  let!(:company) { create(:company) }
  let!(:user) { create(:user, company: company) }

  it 'should run job and return true' do
    res = BulkInvitesJob.new.perform([user.id], company.id)
    expect(res.present?).to eq(true)
  end
end