require 'rails_helper'

RSpec.describe ApprovalChain, type: :model do

  describe 'column specifications' do
    it { is_expected.to have_db_column(:approvable_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:approvable_type).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:approval_type).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:approval_ids).of_type(:string).with_options(presence: true, array: true) }
  end

  describe 'Associations' do
    it { is_expected.to have_many(:ctus_approval_chains).dependent(:destroy)}
  end

  describe 'Enums' do
    it { should define_enum_for(:approval_type).with([:manager, :person, :permission, :individual, :coworker, :requestor_manager]) }
  end

  describe 'Custom Validation' do
    let(:company) { create(:company) }
    let(:custom_table) { create(:custom_table, is_approval_required: true, approval_expiry_time: 7, company: company, approval_chains_attributes: [{ approval_type: ApprovalChain.approval_types[:manager], approval_ids: ['1']}]) }

    context 'should throw validation errors on #create' do
      it 'should throw invalid person validation error if approval ids are less than 1' do
        expect { FactoryGirl.create(:approval_chain, approvable_id: custom_table.id, approvable_type: 'CustomTable',
          approval_type: ApprovalChain.approval_types[:person], approval_ids: []) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval ids are invalid for a person approval type.')
      end

      it 'should throw invalid person validation error if approval ids are greater than 1' do
        expect { FactoryGirl.create(:approval_chain, approvable_id: custom_table.id, approvable_type: 'CustomTable', approval_type: ApprovalChain.approval_types[:person],
         approval_ids: [1, 2, 3]) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval ids are invalid for a person approval type.')
      end

      it 'should throw invalid manager validation error if approval ids are none' do
        expect { FactoryGirl.create(:approval_chain, approvable_id: custom_table.id, approvable_type: 'CustomTable', approval_type: ApprovalChain.approval_types[:manager],
          approval_ids: []) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval ids are invalid for manager approval type.')
      end

      it 'should throw invalid permission validation error if approval ids are none' do
        expect { FactoryGirl.create(:approval_chain, approvable_id: custom_table.id, approvable_type: 'CustomTable', approval_type: ApprovalChain.approval_types[:permission],
          approval_ids: []) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval ids are invalid for permission approval type.')
      end
    end

    context 'should not throw validation errors on #create' do
      it 'should not throw invalid person validation error' do
        expect { FactoryGirl.create(:approval_chain, approvable_id: custom_table.id, approvable_type: 'CustomTable', approval_type: ApprovalChain.approval_types[:person],
          approval_ids: [1]) }.not_to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval ids are invalid for a person approval type.')
      end

      it 'should not throw invalid manager validation error if approval ids are not none' do
        expect { FactoryGirl.create(:approval_chain, approvable_id: custom_table.id, approvable_type: 'CustomTable', approval_type: ApprovalChain.approval_types[:manager], approval_ids: ['1']) }.not_to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval ids are invalid for a manager approval type.')
      end

      it 'should not throw invalid permission validation error if approval ids are none' do
        expect { FactoryGirl.create(:approval_chain, approvable_id: custom_table.id, approvable_type: 'CustomTable', approval_type: ApprovalChain.approval_types[:permission],
          approval_ids: [1]) }.not_to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval ids are invalid for a permission approval type.')
      end
    end
  end
end
