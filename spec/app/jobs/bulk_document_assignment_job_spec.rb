require 'rails_helper'

RSpec.describe BulkInvitesJob, type: :job do

  let!(:document_connection_relation) { create(:document_connection_relation) }
  let!(:company) { create(:company) }
  let!(:user) { create(:user, company: company) }

  it 'should run job and return true' do
    res = BulkDocumentAssignmentJob.new.perform(document_connection_relation.id, [user], user.id, company.id)
    expect(res.present?).to eq(true)
  end
end