require 'rails_helper'

RSpec.describe Location, type: :model do

  let(:company) { FactoryGirl.create(:company)}
  let(:location) {FactoryGirl.create(:location, company: company, is_gdpr_imposed: true)}
  let(:location1) {FactoryGirl.create(:location, company: company, is_gdpr_imposed: false)}


  describe 'Validation' do
    context 'Name' do
      it { is_expected.to validate_presence_of(:name) }
      subject { Location.new(name: "dummy", company_id: company.id )}
      it {is_expected.to validate_uniqueness_of(:name).scoped_to(:company_id, :deleted_at)}
    end
    context 'Company' do
      it { is_expected.to validate_presence_of(:company) }
    end
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:company).counter_cache }
    it { is_expected.to belong_to(:owner).class_name('User') }
    it { is_expected.to have_many(:users).dependent(:nullify) }
    it { is_expected.to have_many(:pending_hires)}
  end

  describe 'callbacks' do
    context 'it runs before and after create callbacks' do
      it 'should update location id of all pending hires if custom fields are present' do
        pending = create(:pending_hire, company: company, custom_fields: {"location": location.name})
        company.pending_hires << pending
        location.run_callbacks(:create)
        expect(pending.location_id).to eq(location.id)
      end
      it 'should not update location id of all pending hires if custom fileds are not present' do
        pending = create(:pending_hire, company: company)
        company.pending_hires << pending
        location.run_callbacks(:create)
        expect(pending.location_id).to eq(nil)
      end
    end

    context 'it runs before and after delete callbacks' do
      it { location.run_callbacks(:destroy)}
      it 'should nulify all pending hires' do
        pending = create(:pending_hire, location_id: location.id, company: company)
        company.pending_hires << pending
        location.run_callbacks(:destroy)
        pending.reload
        expect(pending.location_id).to eq(nil)
      end
      it 'should nulify users Location' do
        user = create(:user, location_id: location.id, company: company)
        location.run_callbacks(:destroy)
        user.reload
        expect(user.location_id).to eq(nil)
      end

      it 'should nulify update enforced general data protection if gdpr impose is true' do
        user = create(:user, location_id: location.id, company: company)
        company.users << user
        location.run_callbacks(:destroy)
        user.reload
        expect(user.location_id).to eq(nil)
      end
      it 'should not updated enforced general data protection if gdpr impose is false' do
        user = create(:user, location_id: location1.id, company: company)
        company.users << user
        location1.run_callbacks(:destroy)
        expect(user.location_id).to_not eq(nil)
      end
    end

    context 'it runs before and after update callbacks' do
      it 'should not nulify location of all pending hires if custom field is not present' do
        pending = create(:pending_hire, location_id: location.id, company: company)
        location.update(name: 'location1')
        expect(pending.location_id).to_not eq(nil)
      end
      it 'should nulify location of all pending hires if custom fields are present' do
        pending = create(:pending_hire, location_id: location.id, company: company, custom_fields: {"location": location.name})
        location.update(name: 'location1')
        pending.reload
        expect(pending.location_id).to eq(nil)
      end
    end

  end
end
