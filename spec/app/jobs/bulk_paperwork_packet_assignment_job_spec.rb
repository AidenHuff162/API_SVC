require 'rails_helper'

RSpec.describe BulkPaperworkPacketAssignmentJob, type: :job do

	let!(:company) { create(:company) }
	let!(:user) { create(:user, company: company) }
	before { allow_any_instance_of(BulkAssignPaperworkPacketService).to receive(:perform) { 'Service Executed'}}

	it 'should execute BulkAssignPaperworkPacketService' do
  	res = BulkPaperworkPacketAssignmentJob.new.perform([user.id], company.id, {})
  	expect(res).to eq('Service Executed')
  end
end