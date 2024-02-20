require 'rails_helper'

RSpec.describe CustomTables::ManageExpiredCustomTableUserSanpshotJob, type: :job do 
  let!(:company) { create(:company, subdomain: 'foo', time_zone: "UTC", is_using_custom_table: true) }
  let!(:user_a) { create(:user, company: company) }
  let (:user_b) { create(:user, company: company) }
  let!(:standard_custom_table_a) { create(:custom_table, company: company, table_type: CustomTable.table_types[:standard], name: 'Standard CustomTable A', approval_expiry_time: 1) }
  let!(:timeline_approval_chain_custom_table_a) { create(:approval_custom_table, company: company, approval_chains_attributes: [{ approval_type: ApprovalChain.approval_types[:person], approval_ids: [user_b.id]}, { approval_type: ApprovalChain.approval_types[:manager], approval_ids: ['1']}, { approval_type: ApprovalChain.approval_types[:person], approval_ids: [user_b.id]}]) }
  let!(:custom_table_user_snapshot) { create(:custom_table_user_snapshot, custom_table: standard_custom_table_a, user: user_a, request_state: CustomTableUserSnapshot.request_states[:requested], requester: user_a, created_at: 3.days.ago) }

  describe "Managed Expired ctus" do

    it "should manage expired snapshot" do
      expect {CustomTables::ManageExpiredCustomTableUserSanpshotJob.new.perform}.to change{custom_table_user_snapshot.activities.with_deleted.count}.by(1)
    end

    it "should not manage expired snapshot" do
      standard_custom_table_a.update(approval_expiry_time: 8)
      expect {CustomTables::ManageExpiredCustomTableUserSanpshotJob.new.perform}.to change{custom_table_user_snapshot.activities.with_deleted.count}.by(0)
    end
  end
end