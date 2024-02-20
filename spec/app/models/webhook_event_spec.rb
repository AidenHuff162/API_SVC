require 'rails_helper'

RSpec.describe WebhookEvent, type: :model do
  let!(:company) { create(:company) }
  let!(:webhook_a) { create(:webhook, company: company) }
  let!(:webhook_event_a1) { create(:webhook_event, company: company, webhook: webhook_a) }
  let!(:webhook_event_a2) { create(:webhook_event, company: company, webhook: webhook_a) }

  describe 'associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to belong_to(:webhook) }
    it { is_expected.to belong_to(:triggered_by).class_name('User') }
    it { is_expected.to belong_to(:triggered_for).class_name('User') }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with([:succeed, :failed, :pending]) }
  end

  describe 'column specifications' do
    it { is_expected.to have_db_column(:status).of_type(:integer) }
    it { is_expected.to have_db_column(:response_status).of_type(:integer) }
    it { is_expected.to have_db_column(:event_id).of_type(:string) }
    it { is_expected.to have_db_column(:triggered_by_source).of_type(:string) }
    it { is_expected.to have_db_column(:triggered_by_reference).of_type(:string) }
    it { is_expected.to have_db_column(:request_body).of_type(:json) }
    it { is_expected.to have_db_column(:response_body).of_type(:json) }
    it { is_expected.to have_db_column(:is_test_event).of_type(:boolean).with_options(default: false) }
    it { is_expected.to have_db_column(:triggered_for_id).of_type(:integer) }
    it { is_expected.to have_db_column(:triggered_by_id).of_type(:integer) }
    it { is_expected.to have_db_column(:webhook_id).of_type(:integer) }
    it { is_expected.to have_db_column(:company_id).of_type(:integer) }
    it { is_expected.to have_db_column(:triggered_at).of_type(:datetime) }
    
    it { is_expected.to have_db_index(:triggered_for_id) }
    it { is_expected.to have_db_index(:triggered_by_id) }
    it { is_expected.to have_db_index(:webhook_id) }
    it { is_expected.to have_db_index(:company_id) }
  end

  describe 'scopes' do
    context 'should return data as per scopes logic' do
      it 'should return data in descending order with respect to triggered_at' do
        webhook_event_a2.update(triggered_at: (DateTime.now+10.minutes))
        expect(webhook_a.webhook_events.with_descending_order.pluck(:triggered_at).map(&:to_s)).to eq([webhook_event_a2.triggered_at.to_s, webhook_event_a1.triggered_at.to_s])
      end
    end
  end

  describe 'callbacks' do
    context 'should run after create' do
      it 'should set unique event_id' do
        expect(webhook_event_a1.event_id).not_to be_nil
      end
    end

    context 'should run after save' do
      it 'should set triggered_by_reference on trigger_by_id change' do
        expect(webhook_event_a1.triggered_by).not_to be_nil
      end
    end
  end
end