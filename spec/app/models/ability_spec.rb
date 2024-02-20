require 'cancan/matchers'
require 'rails_helper'

describe Ability do
  let(:user) { create(:user, company: company) }
  let(:invite) { create(:invite, user: user) }
  let(:team) { create(:team, company: user.company) }
  let(:location) { create(:location, company: user.company) }
  let(:workstream) { create(:workstream, company: user.company) }
  let(:task) { create(:task, workstream: workstream) }
  let(:company_user) { create(:user, company: user.company) }
  let(:company) { create(:company) }
  let(:custom_section) { create(:custom_section, company: company) }

  let(:sarah) { create(:sarah, company: company) }
  let(:peter) { create(:peter, company: company) }
  let(:tim) { create(:tim, company: company) }
  let(:nick) { create(:nick, company: company) }
  let(:user_profile) { create(:profile, user: nick) }
  let(:user_profile_image) { create(:profile_image, entity_id: nick.id, entity_type: 'User') }

  describe 'Sarah (account owner)' do
    subject { Ability.new(sarah) }

    describe 'User' do
      it { is_expected.to be_able_to(:manage, company_user) }
      it { is_expected.not_to be_able_to(:manage, build(:user)) }
    end

    describe 'Invite' do
      it { is_expected.to be_able_to(:manage, invite) }
      it { is_expected.not_to be_able_to(:manage, build(:invite)) }
    end

    describe 'Company' do
      it { is_expected.to be_able_to(:manage, user.company) }
      it { is_expected.not_to be_able_to(:manage, build(:company)) }
    end

    describe 'Team' do
      it { is_expected.to be_able_to(:manage, team) }
      it { is_expected.not_to be_able_to(:manage, build(:team)) }
    end

    describe 'Location' do
      it { is_expected.to be_able_to(:manage, location) }
      it { is_expected.not_to be_able_to(:manage, build(:location)) }
    end

    describe 'Workstream' do
      it { is_expected.to be_able_to(:manage, workstream) }
      it { is_expected.not_to be_able_to(:manage, build(:workstream)) }
    end

    describe 'Task' do
      it { is_expected.to be_able_to(:manage, task) }
      it { is_expected.not_to be_able_to(:manage, build(:task)) }
    end

    describe 'Custom Section' do
      it { is_expected.to be_able_to(:manage, custom_section) }
      it { is_expected.not_to be_able_to(:manage, build(:custom_section)) }
    end
  end

  describe 'Peter (admin)' do
    subject { Ability.new(peter) }

    describe 'User' do
      it { is_expected.to be_able_to(:manage, company_user) }
      it { is_expected.not_to be_able_to(:manage, build(:user)) }
    end

    describe 'Invite' do
      it { is_expected.to be_able_to(:manage, invite) }
      it { is_expected.not_to be_able_to(:manage, build(:invite)) }
    end

    describe 'Company' do
      it { is_expected.to be_able_to(:manage, user.company) }
      it { is_expected.not_to be_able_to(:manage, build(:company)) }
    end

    describe 'Team' do
      it { is_expected.to be_able_to(:manage, team) }
      it { is_expected.not_to be_able_to(:manage, build(:team)) }
    end

    describe 'Location' do
      it { is_expected.to be_able_to(:manage, location) }
      it { is_expected.not_to be_able_to(:manage, build(:location)) }
    end

    describe 'Workstream' do
      it { is_expected.to be_able_to(:manage, workstream) }
      it { is_expected.not_to be_able_to(:manage, build(:workstream)) }
    end

    describe 'Task' do
      it { is_expected.to be_able_to(:manage, task) }
      it { is_expected.not_to be_able_to(:manage, build(:task)) }
    end

    describe 'Custom Section' do
      it { is_expected.to be_able_to(:manage, custom_section) }
      it { is_expected.not_to be_able_to(:manage, build(:custom_section)) }
    end
  end

  describe 'Tim (existing employee)' do
    subject { Ability.new(tim) }

    describe 'User' do
      it { is_expected.not_to be_able_to(:manage, company_user) }
      it { is_expected.not_to be_able_to(:manage, build(:user)) }
    end

    describe 'Invite' do
      it { is_expected.not_to be_able_to(:manage, invite) }
      it { is_expected.not_to be_able_to(:manage, build(:invite)) }
    end

    describe 'Company' do
      it { is_expected.not_to be_able_to(:manage, user.company) }
      it { is_expected.not_to be_able_to(:manage, build(:company)) }
    end

    describe 'Team' do
      it { is_expected.not_to be_able_to(:manage, team) }
      it { is_expected.not_to be_able_to(:manage, build(:team)) }
    end

    describe 'Location' do
      it { is_expected.not_to be_able_to(:manage, location) }
      it { is_expected.not_to be_able_to(:manage, build(:location)) }
    end

    describe 'Workstream' do
      it { is_expected.not_to be_able_to(:manage, workstream) }
      it { is_expected.not_to be_able_to(:manage, build(:workstream)) }
    end

    describe 'Custom Section' do
      it { is_expected.not_to be_able_to(:manage, custom_section) }
      it { is_expected.not_to be_able_to(:manage, build(:custom_section)) }
    end

    # describe 'Task' do
    #   it { is_expected.to be_able_to(:manage, task) }
    #   it { is_expected.to be_able_to(:manage, build(:task)) }
    # end
  end

  describe 'Nick (new employee)' do
    subject { Ability.new(nick) }

    describe 'User' do
      it { is_expected.to be_able_to(:manage, user_profile) }
      it { is_expected.to be_able_to(:manage, user_profile_image) }
      it { is_expected.to be_able_to(:manage, nick) }
      it { is_expected.to be_able_to(:read, build(:user, company: company)) }
    end

    describe 'Company' do
      it { is_expected.to be_able_to(:read, company) }
      it { is_expected.not_to be_able_to(:manage, company) }
      it { is_expected.not_to be_able_to(:read, build(:company)) }
    end
  end
end
