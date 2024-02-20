require 'rails_helper'

RSpec.describe CustomTable, type: :model do
  let(:company) { create(:company) }
  let(:custom_table_with_approval_chain) { create(:custom_table_with_approval_chain, company: company, approval_chains_attributes: [{ approval_type: 0, approval_ids: ['1']}]) }
  let(:custom_table) { create(:custom_table, company: company) }

  
  describe 'column specifications' do
    it { is_expected.to have_db_column(:name).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:table_type).of_type(:integer).with_options(presence: true, default: :timeline) }
    it { is_expected.to have_db_column(:custom_table_property).of_type(:integer).with_options(presence: true, default: :general) }
    it { is_expected.to have_db_column(:position).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:is_deletable).of_type(:boolean).with_options(presence: true, default: true) }
    it { is_expected.to have_db_column(:company_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime).with_options(presence: true, null: false) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime).with_options(presence: true, null: false) }
    it { is_expected.to have_db_column(:is_approval_required).of_type(:boolean).with_options(presence: true, default: false) }
    it { is_expected.to have_db_column(:approval_type).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:approval_ids).of_type(:string).with_options(presence: true, array: true) }
    it { is_expected.to have_db_column(:approval_expiry_time).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:deleted_at).of_type(:datetime).with_options(presence: true) }

    it { is_expected.to have_db_index(:company_id) }
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:company)}
    it { is_expected.to have_many(:custom_fields).dependent(:destroy)}
    it { is_expected.to have_many(:custom_table_user_snapshots).dependent(:destroy)}
    it { is_expected.to have_many(:approval_chains).dependent(:destroy)}
  end

  describe 'Validations' do
    let 'validate name' do
      it { is_expected.to validate_presence_of(:name) }
    end

    let 'validate table type' do
      it { is_expected.to validate_presence_of(:table_type) }
    end

    let 'validate name uniqueness' do
      is_expected.to validate_uniqueness_of(:name).ignoring_case_sensitivity.scoped_to(:company_id)
    end
  end

  describe 'Nested Attributes' do
    it { should accept_nested_attributes_for(:approval_chains).allow_destroy(true) }
  end

  describe 'Custom Validation' do
    context 'should throw validation errors on #create' do

      it 'should throw expiry time validation error' do
        expect { FactoryGirl.create(:approval_custom_table, company: company, approval_expiry_time: nil, approval_chains_attributes: [{ approval_type: 0, approval_ids: ['1']}]) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval expiry time cannot be empty.')
      end

      it 'should throw expiry time validation error if expiry time is 0' do
        expect { FactoryGirl.create(:approval_custom_table, company: company, approval_expiry_time: 0, approval_chains_attributes: [{ approval_type: 0, approval_ids: ['1']}]) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval expiry time cannot be empty.')
      end

      it 'should throw approval chain validation error if empty' do
        expect { FactoryGirl.create(:custom_table, company: company, is_approval_required: true, approval_expiry_time: 7) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval chain cannot be empty.')
      end
    end

    context 'should not throw validation errors on #create' do

      it 'should not throw expiry time validation error' do
        expect { FactoryGirl.create(:custom_table, company: company, is_approval_required: true, approval_expiry_time: 1) }.not_to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval expiry time cannot be empty.')
      end

      it 'should not throw approval chain validation error' do
        expect { FactoryGirl.create(:approval_custom_table, company: company, approval_chains_attributes: [{ approval_type: 0, approval_ids: ['1']}]) }.not_to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval chain cannot be empty.')
      end
    end

    context 'should throw validation errors on #update (from non approval to approval)' do

      it 'should throw expiry time validation error' do
        expect { custom_table.update!(is_approval_required: true, approval_expiry_time: nil, approval_chains_attributes: [{ approval_type: 0, approval_ids: ['1']}]) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval expiry time cannot be empty.')
      end

      it 'should throw expiry time validation error if expiry time is 0' do
        expect { custom_table.update!(is_approval_required: true, approval_expiry_time: 0, approval_chains_attributes: [{ approval_type: 0, approval_ids: ['1']}]) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval expiry time cannot be empty.')
      end

      it 'should throw approval chain validation error if empty' do
        expect { custom_table.update!(is_approval_required: true, approval_expiry_time: 1) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval chain cannot be empty.')
      end
    end

    context 'should throw validation errors on #update (from approval to approval)' do
      it 'should throw expiry time validation error' do
        expect { custom_table_with_approval_chain.update!(approval_expiry_time: nil) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval expiry time cannot be empty.')
      end

      it 'should throw expiry time validation error if expiry time is 0' do
        expect { custom_table_with_approval_chain.update!(approval_expiry_time: 0) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval expiry time cannot be empty.')
      end
    end

    context 'should not throw validation errors on #update (from non approval to approval)' do
      it 'should not throw expiry time validation error' do
        expect { custom_table_with_approval_chain.update!(is_approval_required: true, approval_expiry_time: 7, approval_chains_attributes: [{ approval_type: 0, approval_ids: ['1']}]) }.not_to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval expiry time cannot be empty.')
      end

      it 'should not throw approval chain validation error' do
        expect { custom_table_with_approval_chain.update!(is_approval_required: true, approval_expiry_time: 7, approval_chains_attributes: [{ approval_type: 0, approval_ids: ['1']}]) }.not_to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval chain cannot be empty.')
      end
    end

    context 'should not throw validation errors on #update (from approval to approval)' do

      it 'should not throw expiry time validation error' do
        expect { custom_table_with_approval_chain.update!(approval_expiry_time: 7) }.not_to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval expiry time cannot be empty.')
      end

      it 'should not throw approval chain validation error' do
        expect { custom_table_with_approval_chain.approval_chains.first.update(approval_type: ApprovalChain.approval_types[:manager], approval_ids: ['1']) }.not_to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Approval chain cannot be empty.')
      end
    end
  end

  describe 'Enums' do
    it { should define_enum_for(:table_type).with([:timeline, :standard]) }
    it { should define_enum_for(:custom_table_property).with([:general, :compensation, :role_information, :employment_status]) }
    it { should define_enum_for(:approval_type).with([:manager, :person, :permission]) }
  end

  describe 'Callbacks - After Create' do
    context 'manage default timeline custom table column' do
      let(:company) { create(:company) }

      it 'should create effective date column for timeline type custom table' do
        custom_table = FactoryGirl.create(:custom_table, company: company)
        expect(company.custom_fields.where(custom_table_id: custom_table.id, name: 'Effective Date').count).to eq(1)
      end

      it 'should not create effective date column for standard type custom table' do
        custom_table = FactoryGirl.create(:custom_table, table_type: CustomTable.table_types[:standard], company: company)
        expect(company.custom_fields.where(custom_table_id: custom_table.id, name: 'Effective Date').count).to eq(0)
      end
    end

    context 'manage timeline custom table permissions' do
      let(:company) { create(:company) }

      before do
        @custom_table = FactoryGirl.create(:custom_table, company: company)
      end

      it 'should create other role visibility permissions of timeline custom table' do
        company.user_roles.find_each do |user_role|
          if user_role.super_admin?
            expect(user_role.permissions['other_role_visibility'][@custom_table.id.to_s]).to eq('view_and_edit')
          else
            expect(user_role.permissions['other_role_visibility'][@custom_table.id.to_s]).to eq('no_access')
          end
        end
      end

      it 'should create own role visibility permissions of timeline custom table' do
        company.user_roles.find_each do |user_role|
           if user_role.super_admin?
            expect(user_role.permissions['own_role_visibility'][@custom_table.id.to_s]).to eq('view_and_edit')
          else
            expect(user_role.permissions['own_role_visibility'][@custom_table.id.to_s]).to eq('no_access')
          end
        end
      end
    end

    context 'manage standard custom table permissions' do
      let(:company) { create(:company) }

      before do
        @custom_table = FactoryGirl.create(:custom_table, table_type: CustomTable.table_types[:standard], company: company)
      end

      it 'should create other role visibility permissions of standard custom table' do
        company.user_roles.find_each do |user_role|
          if user_role.super_admin?
            expect(user_role.permissions['other_role_visibility'][@custom_table.id.to_s]).to eq('view_and_edit')
          else
            expect(user_role.permissions['other_role_visibility'][@custom_table.id.to_s]).to eq('no_access')
          end
        end
      end

      it 'should create own role visibility permissions of standard custom table' do
        company.user_roles.find_each do |user_role|
           if user_role.super_admin?
            expect(user_role.permissions['own_role_visibility'][@custom_table.id.to_s]).to eq('view_and_edit')
          else
            expect(user_role.permissions['own_role_visibility'][@custom_table.id.to_s]).to eq('no_access')
          end
        end
      end
    end
  
  end

  describe 'Callbacks - After Update' do
    context 'manage approval type requested snapshots' do
      let(:company) { create(:company) }

      it 'should destroy requested custom table user snapshots' do
        @custom_table = FactoryGirl.create(:approval_custom_table_with_requested_custom_table_user_snapshots, is_approval_required: true, approval_expiry_time: 1, company: company, approval_chains_attributes: [{ approval_type: 0, approval_ids: ['1']}])
        @custom_table.update!(is_approval_required: nil)
        expect(@custom_table.custom_table_user_snapshots.where(request_state: CustomTableUserSnapshot.request_states[:requested]).count).to eq(0)
      end
    end

    context 'manage non_approval type snapshots' do
      let(:company) { create(:company) }

      it 'should approved non approval custom table user snapshots' do
        @custom_table = FactoryGirl.create(:non_approval_custom_table_with_custom_table_user_snapshots, company: company, approval_chains_attributes: [{ approval_type: 0, approval_ids: ['1']}])
        @custom_table.update!(is_approval_required: true, approval_expiry_time: 1, approval_chains_attributes: [{ approval_type: 0, approval_ids: ['1']}])
        expect(@custom_table.custom_table_user_snapshots.where(request_state: nil).count).to eq(0)
      end
    end
  end

  describe 'Callbacks - After Destroy' do
    context 'remove timeline custom table permissions' do
      let(:company) { create(:company) }

      before do
        @custom_table = FactoryGirl.create(:custom_table, company: company)
        @custom_table.destroy!
      end

      it 'should destroy other role visibility permissions of timeline custom table' do
        company.user_roles.find_each do |user_role|
          expect(user_role.permissions['other_role_visibility'][@custom_table.id.to_s]).to eq(nil)
        end
      end

      it 'should destroy own role visibility permissions of standard custom table' do
        company.user_roles.find_each do |user_role|
          expect(user_role.permissions['own_role_visibility'][@custom_table.id.to_s]).to eq(nil)
        end
      end
    end

    context 'remove standard custom table permissions' do
      let(:company) { create(:company) }

      before do
        @custom_table = FactoryGirl.create(:custom_table, table_type: CustomTable.table_types[:standard], company: company)
        @custom_table.destroy!
      end

      it 'should destroy other role visibility permissions of standard custom table' do
        company.user_roles.find_each do |user_role|
          expect(user_role.permissions['other_role_visibility'][@custom_table.id.to_s]).to eq(nil)
        end
      end

      it 'should destroy own role visibility permissions of standard custom table' do
        company.user_roles.find_each do |user_role|
          expect(user_role.permissions['own_role_visibility'][@custom_table.id.to_s]).to eq(nil)
        end
      end
    end
    
  end
end

