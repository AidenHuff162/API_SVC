require 'rails_helper'
require 'cancan/matchers'

RSpec.describe Api::V1::Admin::LocationsController, type: :controller do
  let(:company) { create(:company) }
  let(:company2) { create(:company, subdomain: 'foo2')}
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:user1) { create(:user, state: :active, current_stage: :registered, company: company2) }
  let(:user2) { create(:user, state: :active, current_stage: :registered, role: 'employee', company: company) }
  let(:location) {create(:location, company: user.company, name: 'location1')}
  let(:location2) { create (:location)}
  let(:location3) { create(:location, company: company2)}

  before do
    allow(controller).to receive(:current_company).and_return(user.company)
    location.reload
    location2.reload
    location3.reload
  end

  describe 'Authorization' do
    context 'Authorized User' do
      it 'should allow account owner/super admin to create' do
        ability = Ability.new(user)
        expect(ability).to be_able_to(:create, location)
      end
      it 'should allow account owner/super admin to update' do
        ability = Ability.new(user)
        expect(ability).to be_able_to(:update, location)
      end
    end
    context 'unAuthorized User' do
      it 'should not allow to create lcoation if not account owner/super admin' do
        ability2 = Ability.new(user2)
        expect(ability2).to_not be_able_to(:create, location)
      end
      it 'should not allow to update lcoation if not account owner/super admin' do
        ability2 = Ability.new(user2)
        expect(ability2).to_not be_able_to(:update, location)
      end
      it 'should not allow account owner/super admin from other company to create' do
        ability = Ability.new(user1)
        expect(ability).to_not be_able_to(:create, location)
      end
      it 'should not allow account owner/super admin from other company to update' do
        ability = Ability.new(user1)
        expect(ability).to_not be_able_to(:update, location)
      end
    end
  end


  describe 'POST #create' do
    context 'Authenticated User' do
      it 'should not create a new location if name is not present' do
        allow(controller).to receive(:current_user).and_return(user)
        post :create, params: { name: '' }, format: :json
        expect(response.message).to eq('Unprocessable Entity')
      end

      it 'should create a new location if name is present' do
        allow(controller).to receive(:current_user).and_return(user)
        post :create, params: { name: 'locationX' }, format: :json
        expect(response.message).to eq('Created')
      end
    end
    context 'UnAuthenticated User' do
      it 'should not create new location' do
        allow(controller).to receive(:current_user).and_return(nil)
        post :create, params: { name: 'locationX' }, format: :json
        expect(response.status).to eq(401)
      end
    end
  end

  describe 'Get locations' do
    context 'Authenticated User' do
      it 'should get the locations of current company only' do
        allow(controller).to receive(:current_user).and_return(user)
        get :index, format: :json
        expect(JSON.parse(response.body).first['id']).to eq(location.id)
      end
      it 'should not get the locations of other companies' do
        allow(controller).to receive(:current_user).and_return(user)
        get :index, format: :json
        expect(JSON.parse(response.body)).not_to include(location3.id)
      end
    end
    context 'UnAuthenticated User' do
      it 'should not return the locations' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :index, format: :json
        expect(response.status).to eq(401)
      end
    end
  end

  describe "Get show" do
    context 'Authenticated User' do
      it 'should return the location with id provided' do
        allow(controller).to receive(:current_user).and_return(user)
        get :show, params: { id: location.id }, format: :json
        expect(JSON.parse(response.body)["id"]).to be(location.id)
      end
    end
    context 'UnAuthenticated User' do
      it 'should not return location with id provided' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :show, params: { id: location.id }, format: :json
        expect(response.status).to be(401)
      end
      it 'should not return location if lcoation is from different company' do
        allow(controller).to receive(:current_user).and_return(user1)
        get :show, params: { id: location.id }, format: :json
        expect(response.body).eql?("")
      end
    end
  end

  describe 'POST #update' do
    context 'Authenticated User' do
      it 'should update name of location' do
        allow(controller).to receive(:current_user).and_return(user)
        post :update, params: { id: location.id, name: 'updated location1' }, format: :json
        expect(JSON.parse(response.body)["name"]).to eq("updated location1")
      end
    end
    context 'UnAuthenticated User' do
      it 'should not update name of location' do
        allow(controller).to receive(:current_user).and_return(nil)
        post :update, params: { id: location.id, name: 'updated location1' }, format: :json
        expect(response.status).to be(401)
      end
      it 'should not update if user is from different company' do
        allow(controller).to receive(:current_user).and_return(user1)
        post :update, params: { id: location.id, name: 'updated location1' }, format: :json
        expect(response.body).eql?("")
      end
    end
  end

   describe 'DELETE #destroy' do
    context 'Authenticated User' do
      it 'should destroy a location based on id' do
        allow(controller).to receive(:current_user).and_return(user)
        delete :destroy, params: { id: location.id  }, format: :json
        expect(Location.find_by(id: location.id)).to eq(nil)
      end
    end
    context 'UnAuthenticated User' do
      it 'should not destroy a location based on id' do
        allow(controller).to receive(:current_user).and_return(nil)
        delete :destroy, params: { id: location.id  }, format: :json
        expect(Location.find_by(id: location.id).id).to eq(location.id)
      end
      it 'should not destroy a location if user is from different company' do
        allow(controller).to receive(:current_user).and_return(user1)
        delete :destroy, params: { id: location.id  }, format: :json
        expect(Location.find_by(id: location.id).id).to eq(location.id)
      end
    end
  end

  describe 'Get state' do
    it 'should get states for country' do
      get :states, params: { country_name: 'United Kingdom' }, format: :json

      expect(JSON.parse(response.body)).not_to be_empty
    end
  end

  describe 'Get state' do
    context 'Authenticated User' do
      it 'should get states for country' do
        allow(controller).to receive(:current_user).and_return(user)
        get :states, params: { country_name: 'United Kingdom' }, format: :json
        expect(JSON.parse(response.body)).not_to be_empty
      end
    end
    context 'UnAuthenticated User' do
      it 'should not get states for country' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :states, params: { country_name: 'United Kingdom' }, format: :json
        expect(response.status).to be(401)
      end
    end
  end

  describe 'search location' do
    context 'Authenticated User' do
      it 'should search location' do
        allow(controller).to receive(:current_user).and_return(user)
        get :search, params: { query: 'loc' }, format: :json
        expect(JSON.parse(response.body).length).to eq(1)
      end
    end
    context 'UnAuthenticated User' do
      it 'should not search location' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :search, params: { query: 'loc' }, format: :json
        expect(response.status).to eq(401)
      end
    end
  end

  describe 'Perform Jobs' do
    before do
      allow(controller).to receive(:current_user).and_return(user)
      stub_request(:post, "http://example.com/webhook").to_return(body: %Q({:response=>{:valid_response=>'true'}}))
      Integration.create(api_name: "slack_communication", webhook_url: 'http://example.com/webhook', channel: 'channel', company_id: company.id)
    end
    it 'should check create location history creation' do
      post :create, params: { name: 'locationX' }, format: :json
      expect(user.company.histories.last.description).eql?(I18n.t('history_notifications.location.created', name: Location.last[:name], users_count: Location.last[:users_count]))
    end

    it 'should check update location history creation' do
      post :update, params: { id: location.id, name: 'updated location1' }, format: :json
      expect(user.company.histories.last.description).eql?(I18n.t('history_notifications.location.updated', name: location[:name], users_count: location[:users_count]))
    end

    it 'should check destroy location history creation' do
      delete :destroy , params: { id: location.id  }, format: :json
      expect(user.company.histories.last.description).eql?(I18n.t('history_notifications.location.deleted', name: location[:name], users_count: location[:users_count]))
    end
  end

end
