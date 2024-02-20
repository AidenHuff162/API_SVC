require 'rails_helper'
RSpec.describe PeriodicJobs::CustomTable::ManageExpiredApprovalTypeCtus, type: :job do
  it 'should enque ManageExpiredApprovalTypeCtus job in sidekiq' do
    expect{ PeriodicJobs::CustomTable::ManageExpiredApprovalTypeCtus.new.perform }.to have_enqueued_job(CustomTables::ManageExpiredCustomTableUserSanpshotJob)
  end
end