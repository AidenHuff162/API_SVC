require 'rails_helper'

RSpec.describe Team, type: :model do
  let(:company) { FactoryGirl.create(:company)}
  let(:team) { FactoryGirl.create(:team, company: company)}

  describe 'Validation' do
    describe 'Name' do
      it { is_expected.to validate_presence_of(:name) }
      subject { Team.new(name: "dummy", company_id: company.id )}
      it { is_expected.to validate_uniqueness_of(:name).scoped_to(:company_id)}
    end

    describe 'Company' do
      it { is_expected.to validate_presence_of(:company) }
    end
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:company).counter_cache }
    it { is_expected.to belong_to(:owner).class_name('User') }
    it { is_expected.to have_many(:users).dependent(:nullify) }
  end

  describe 'callbacks' do
    context 'should check all callbacks' do
      it 'shoud nullify user team' do
        user = create(:user, company: company, team_id: team.id)
        company.users << user
        team.run_callbacks(:destroy)
        user.reload
        expect(user.team_id).to eq(nil)
      end
    end
  end
end
