require 'rails_helper'

RSpec.describe Webhook, type: :model do

  describe 'associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to belong_to(:created_by).class_name('User') }
    it { is_expected.to belong_to(:updated_by).class_name('User') }
    it { is_expected.to have_many(:webhook_events).dependent(:destroy) }
  end

  describe 'enums' do
    it { should define_enum_for(:state).with([:active, :inactive]) }
    it { should define_enum_for(:event).with([:stage_completed, :new_pending_hire, :stage_started, :key_date_reached, :profile_changed, :job_details_changed, :onboarding, :offboarding]) }
    it { should define_enum_for(:created_from).with([:app, :api_call]) }
  end

  describe 'column specifications' do
    it { is_expected.to have_db_column(:event).of_type(:integer).with_options(null: false) }
    it { is_expected.to have_db_column(:target_url).of_type(:string).with_options(null: true) }
    it { is_expected.to have_db_column(:state).of_type(:integer).with_options(default: :active) }
    it { is_expected.to have_db_column(:created_from).of_type(:integer).with_options(default: :app) }
    it { is_expected.to have_db_column(:description).of_type(:string) }
    it { is_expected.to have_db_column(:created_by_reference).of_type(:string) }
    it { is_expected.to have_db_column(:updated_by_reference).of_type(:string) }
    it { is_expected.to have_db_column(:guid).of_type(:string) }
    it { is_expected.to have_db_column(:created_by_id).of_type(:integer) }
    it { is_expected.to have_db_column(:updated_by_id).of_type(:integer) }
    it { is_expected.to have_db_column(:company_id).of_type(:integer) }
    
    it { is_expected.to have_db_index(:company_id) }
    it { is_expected.to have_db_index(:created_by_id) }
    it { is_expected.to have_db_index(:updated_by_id) }
  end

  describe 'callbacks' do
    context 'should run after create' do
      it "should set unique webhook guid" do
        webhook = create(:webhook, company: create(:company))
        expect(webhook.guid).not_to be_nil
      end

      it "should set references" do
        webhook = create(:webhook, company: create(:company))
        expect(webhook.created_by_reference).not_to be_nil
        expect(webhook.updated_by_reference).not_to be_nil
      end
    end
  end
end
