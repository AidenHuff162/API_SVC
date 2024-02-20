require 'rails_helper'
#assign stub
RSpec.describe TeamSpiritService::Main do
  describe 'fetch the starter leavers and changes' do
    let(:company) { create(:company, subdomain: 'team-spirit-company') }
    let(:location) { create(:location, name: 'London', company: company) }
    let(:location2) { create(:location, name: 'Chicago', company: company) }
    let(:team) {create(:team, name: 'Operations', company_id: company.id)}
    let(:team2) {create(:team, name: '"Engineering"', company_id: company.id)}
    let!(:integration_instance) {create(:team_spirit_integration, company: company,filters: {location_id: [location.id], team_id: [team.id], employee_type: ['all']})}
    let!(:nick) { create(:nick, company: integration_instance.company, location: location,team_id: team.id ,start_date: 6.years.ago, termination_date: 2.days.ago) }
    let!(:tim) { create(:tim, company: integration_instance.company,location: location2,team_id: team2.id ,start_date: 5.days.ago) }
    let!(:jake) { create(:user, company: integration_instance.company, start_date: 6.days.ago) }
    let!(:change_history) { create(:field_history, field_changer_id: nick.id, field_auditable_type: 'User',field_auditable_id: tim.id, created_at: 2.days.ago, updated_at:2.days.ago) }


    context 'fetch all the starters of past week' do
      it 'should fetch all the past week entries of starters' do

        obj = TeamSpiritService::Main.new(integration_instance)
        user = integration_instance.company.users.hired_in_a_week
        expect(user.find_by(email: 'tim@test.com')).to eq(tim)
      end

      it 'should not fetch all the entries of starters before past week' do

        obj = TeamSpiritService::Main.new(integration_instance)
        user = integration_instance.company.users.hired_in_a_week
        expect(user.find_by(first_name: 'Nick')).to eq(nil)
      end

    end

    context 'fetch all the leavers of past week' do
      it 'should fetch all the past week entries of leavers' do

        obj = TeamSpiritService::Main.new(integration_instance)
        user = integration_instance.company.users.offboarded_in_a_week
        expect(user.find_by(first_name: 'Nick')).to eq(nick)
      end

      it 'should not fetch all the entries of leavers before past week' do

        obj = TeamSpiritService::Main.new(integration_instance)
        user = integration_instance.company.users.offboarded_in_a_week
        expect(user.find_by(email: 'tim@test.com')).to eq(nil)
      end

    end

    context 'fetch all the changes of past week' do
      it 'should fetch all the past week entries of changes' do
        obj = TeamSpiritService::Main.new(integration_instance)
        change = integration_instance.company.users.updated_in_a_week
        expect(change.count).to eq(1)
      end

    end

    context 'using filter location' do
      it 'should fetch all the entries of location filter' do
        obj = TeamSpiritService::Helper.new
        expect(obj.can_send_data?(integration_instance, nick)).to eq(true)
      end

      it 'should not fetch all the entries of location filter' do
        obj = TeamSpiritService::Helper.new
        expect(obj.can_send_data?(integration_instance, tim)).to eq(false)
      end

    end

    context 'using filter team' do
      it 'should fetch all the entries of team filter' do
        obj = TeamSpiritService::Helper.new
        expect(obj.can_send_data?(integration_instance, nick)).to eq(true)
      end

      it 'should not fetch all the entries of team filter' do
        obj = TeamSpiritService::Helper.new
        expect(obj.can_send_data?(integration_instance, tim)).to eq(false)
      end

    end

    context 'using filter' do
      it 'should fetch all the entries of filter' do
        obj = TeamSpiritService::Helper.new
        expect(obj.can_send_data?(integration_instance, nick)).to eq(true)
      end

      it 'should not fetch all the entries of filter' do
        obj = TeamSpiritService::Helper.new
        expect(obj.can_send_data?(integration_instance, tim)).to eq(false)
      end

    end
  end
end
