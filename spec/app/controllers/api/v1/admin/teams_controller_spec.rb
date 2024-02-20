require 'rails_helper'
require 'cancan/matchers'

RSpec.describe Api::V1::Admin::TeamsController, type: :controller do
  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:user1) { create(:user, state: :active, current_stage: :registered, company: company2) }
  let(:user2) { create(:user, state: :active, current_stage: :registered, role: 'employee', company: company) }
  let(:company2) { create(:company, subdomain: "foo2") }
  let(:team) { create(:team, name: 'team1', company: company)}
  let(:team2) { create(:team, name: 'team2', company: company2)}
  let(:valid_session) { {} }

  before do
    allow(controller).to receive(:current_company).and_return(user.company)
    team.reload
    team2.reload
  end

  describe 'Authorization' do
    context 'Authorized User' do
      it 'should allow account owner/super admin to create' do
        allow(controller).to receive(:current_user).and_return(user)
        ability = Ability.new(user)
        expect(ability).to be_able_to(:create, team)
      end
      it 'should allow account owner/super admin to update' do
        allow(controller).to receive(:current_user).and_return(user)
        ability = Ability.new(user)
        expect(ability).to be_able_to(:update, team)
      end
    end
    context 'unAuthorized User' do
      it 'should not allow to create team if not account owner/super admin' do
        allow(controller).to receive(:current_user).and_return(user2)
        ability2 = Ability.new(user2)
        expect(ability2).to_not be_able_to(:create, team)
      end
      it 'should not allow to update team if not account owner/super admin' do
        allow(controller).to receive(:current_user).and_return(user2)
        ability2 = Ability.new(user2)
        expect(ability2).to_not be_able_to(:update, team)
      end
      it 'should not allow account owner/super admin from other company to create' do
        ability = Ability.new(user1)
        expect(ability).to_not be_able_to(:create, team)
      end
      it 'should not allow account owner/super admin from other company to update' do
        ability = Ability.new(user1)
        expect(ability).to_not be_able_to(:update, team)
      end
    end
  end

  describe 'POST #create' do
    context 'Authenticated User' do
      before do
        allow(controller).to receive(:current_user).and_return(user)
      end
      it 'should not create a new team if name is not present' do
        post :create, params: { name: '' }, format: :json
        expect(response.message).to eq('Unprocessable Entity')
      end

      it 'should create a new team if name is present' do
        post :create, params: { name: 'asdasd' }, format: :json
        expect(response.message).to eq('Created')
      end
    end
    context 'UnAuthenticated User' do
      it 'should not create a new team' do
        allow(controller).to receive(:current_user).and_return(nil)
        post :create, params: { team_id: team.id, name: 'adsdasd' }, format: :json
        expect(response.status).to eq(401)
      end
    end
  end

  describe 'Get teams' do
    context 'Authenticated User' do
      before do
        allow(controller).to receive(:current_user).and_return(user)
      end
      it 'should get all teams of current company' do
        get :index, params: valid_session, format: :json
        expect(JSON.parse(response.body).first['id']).to eq(team.id)
      end
      it 'should not get the team of other companies' do
        get :index, params: valid_session, format: :json
        expect(JSON.parse(response.body)).not_to include(team2.id)
      end
      it 'should get teams of current company' do
        get :get_teams, format: :json
        expect(JSON.parse(response.body).first['id']).to eq(team.id)
      end
      it 'should get basic index of current company' do
        get :basic_index, format: :json
        expect(JSON.parse(response.body).first['id']).to eq(team.id)
      end
    end
    context 'UnAuthenticated User' do
      it 'should not create a new team' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :index, params: valid_session, format: :json
        expect(response.status).to eq(401)
      end
    end
  end

  describe 'Get show' do
    context 'Authenticated User' do
      it 'should return the team with id provided' do
        allow(controller).to receive(:current_user).and_return(user)
        get :show, params: { id: team.id }, format: :json
        expect(JSON.parse(response.body)["id"]).to be(team.id)
      end
    end
    context 'UnAuthenticated User' do
      it 'should not return team with id provided' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :show, params: { id: team.id }, format: :json
        expect(response.status).to be(401)
      end
    end
  end

  describe 'POST #update' do
    context 'Authenticated User' do
      it 'should update name of team' do
        allow(controller).to receive(:current_user).and_return(user)
        post :update, params: { format: :json, id: team.id, name: 'updated team1'}
        expect(JSON.parse(response.body)["name"]).to eq("updated team1")
      end
    end
    context 'UnAuthenticated User' do
      it 'should not update name of team' do
        allow(controller).to receive(:current_user).and_return(nil)
        post :update, params: { format: :json, id: team.id, name: 'updated team1'}
        expect(response.status).to be(401)
      end
      it 'should not update name of team if user is from different company' do
        allow(controller).to receive(:current_user).and_return(user1)
        post :update, params: { format: :json, id: team.id, name: 'updated team1'}
        expect(response.body).eql?("")
      end
    end
  end

  describe 'search team' do
    context 'Authenticated User' do
      it 'should search team' do
        allow(controller).to receive(:current_user).and_return(user)
        get :search, params: { format: :json, query: 'team'}
        expect(JSON.parse(response.body).length).to eq(1)
      end
    end
    context 'UnAuthenticated User' do
      it 'should search team' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :search, params: { format: :json, query: 'team'}
        expect(response.status).to eq(401)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'Authenticated User' do
      it 'should destroy a team based on id' do
        allow(controller).to receive(:current_user).and_return(user)
        delete :destroy, params: { id: team.id  }, format: :json
        expect(Team.find_by(id: team.id)).to eq(nil)
      end
    end
    context 'UnAuthenticated User' do
      it 'should not destroy a team based on id' do
        allow(controller).to receive(:current_user).and_return(nil)
        delete :destroy, params: { id: team.id  }, format: :json
        expect(Team.find_by(id: team.id).id).to eq(team.id)
      end
      it 'should not destroy a team if user is from different company' do
        allow(controller).to receive(:current_user).and_return(user1)
        delete :destroy, params: { id: team.id  }, format: :json
        expect(Team.find_by(id: team.id).id).to eq(team.id)
      end
    end
  end

  describe 'perform history job' do
    before do
      allow(controller).to receive(:current_user).and_return(user)
    end
    it 'should check create team history creation' do
      post :create, params: { name: 'teamX' }, format: :json
      expect(user.company.histories.last.description).eql?(I18n.t('history_notifications.team.created', name: Team.last[:name], users_count: Team.last[:users_count]))
    end

    it 'should check update team history creation' do
      post :update, params: { id: team.id, name: 'updated team1' }, format: :json
      expect(user.company.histories.last.description).eql?(I18n.t('history_notifications.team.updated', name: team[:name], users_count: team[:users_count]))
    end
    it 'should check destroy team history creation' do
      delete :destroy, params: { id: team.id  }, format: :json
      expect(user.company.histories.last.description).eql?(I18n.t('history_notifications.team.deleted', name: team[:name], users_count: team[:users_count]))
    end
  end
end
