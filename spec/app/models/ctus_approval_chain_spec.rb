require 'rails_helper'

RSpec.describe CtusApprovalChain, type: :model do

  let (:company) { create(:company) }
  let (:user_a) { create(:user, company: company) }
  let (:user_b) { create(:user, company: company) }
  let (:user_c) { create(:user, company: company) }
  let (:manager) { create(:user, company: company) }
  let (:timeline_approval_custom_table_a) { create(:custom_table, company: company, table_type: CustomTable.table_types[:timeline], name: 'Approval Timeline CustomTable A', is_approval_required: true, approval_expiry_time: 1, approval_chains_attributes: [{ approval_type: ApprovalChain.approval_types[:manager], approval_ids: ["1"]}]) }
  let!(:person_approval_chain_a) { create(:approval_chain, approvable_id: timeline_approval_custom_table_a.id, approvable_type: 'CustomTable', approval_type: ApprovalChain.approval_types[:person], approval_ids: [user_b.id]) }
  let!(:manager_approval_chain_a) { create(:approval_chain, approvable_id: timeline_approval_custom_table_a.id, approvable_type: 'CustomTable', approval_type: ApprovalChain.approval_types[:manager], approval_ids: ["1"]) }
  let!(:person_approval_chain_b) { create(:approval_chain, approvable_id: timeline_approval_custom_table_a.id, approvable_type: 'CustomTable', approval_type: ApprovalChain.approval_types[:person], approval_ids: [user_c.id]) }

  describe 'column specifications' do
    it { is_expected.to have_db_column(:approval_chain_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:custom_table_user_snapshot_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:request_state).of_type(:integer).with_options(presence: true) }

    it { is_expected.to have_db_index(:approval_chain_id) }
    it { is_expected.to have_db_index(:custom_table_user_snapshot_id) }

  end

  describe 'Associations' do
    it { is_expected.to belong_to(:custom_table_user_snapshot)}
    it { is_expected.to belong_to(:approval_chain)}
  end

  describe "attributes accessors" do
    subject { CtusApprovalChain.new }

    it "should check previous_approval_chain to be true" do
      subject.previous_approval_chain = true
      expect(subject.previous_approval_chain).to eq(true)
    end
  end

  describe 'Enums' do
    it { should define_enum_for(:request_state).with([:denied, :requested, :approved, :skipped]) }
  end

  describe "scopes" do
    context "#current_approval_chain" do
      it "should return current requsted chain" do
        user_a.update(manager_id: manager.id)
        custom_table_user_snapshot_a = create(:custom_table_user_snapshot, effective_date: 2.days.ago, user: user_a, custom_table: timeline_approval_custom_table_a, request_state: CustomTableUserSnapshot.request_states[:requested], requester_id: user_a.id)
        expect(CtusApprovalChain.current_approval_chain(custom_table_user_snapshot_a.id).first.approval_chain.approval_type).to eq('manager')
      end
    end
  end

  describe "callbacks" do
    before do
      user_a.update(manager_id: manager.id)
      Sidekiq::Testing.inline! do
        custom_table_user_snapshot_a = create(:custom_table_user_snapshot, effective_date: 2.days.ago, user: user_a, custom_table: timeline_approval_custom_table_a, request_state: CustomTableUserSnapshot.request_states[:requested], requester_id: user_a.id)
      end
      @delivery_count = CompanyEmail.all.count
    end

    context "after_destroy #send_request_emails" do
      it "should send request email after destroying current effective chain" do
        Sidekiq::Testing.inline! do
          expect{timeline_approval_custom_table_a.approval_chains.order('id asc').take.destroy}.to change{CompanyEmail.all.count}.by(1)
        end
      end

      it "should not send request email after destroying non effective chain" do
        Sidekiq::Testing.inline! do
          manager_approval_chain_a.destroy
        end
        expect(CompanyEmail.all.count).to eq(@delivery_count)
      end
    end
  end

end
