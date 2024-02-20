require 'rails_helper'

RSpec.describe Api::V1::Auth::TokenValidationsController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:nick, company: company) }
  
  describe "validate token" do

    context 'with ids authentication when ids feature flag is true' do
      before do
        allow_any_instance_of(IdentityServer::Authenticator).to receive(:perform).and_return(user)
        allow(controller).to receive(:current_company).and_return(company)
        company.stub(:ids_authentication_feature_flag) { true }
      end

      context 'with access_token in query params' do
        it "should validate token and return user" do
          allow(controller).to receive(:resource).and_return(user)
          allow(controller).to receive(:set_user_by_token).and_return(controller.instance_eval { @resource = resource})
          request.headers['Authorization'] = JsonWebToken.encode({access_token: 'give_access_token', Time: Time.now.to_i})
          response = get :validate_token, params: { cacheBuster: 2434234 }, format: :json
          result = JSON.parse response.body
          expect(result['id']).to eq(user.id)
        end
      end
    end

    context 'with device authentication when feature flag is false' do
      before do
        allow(controller).to receive(:current_company).and_return(company)
        company.stub(:ids_authentication_feature_flag) { false }
      end

      it "should validate token and return user" do
        allow(controller).to receive(:resource).and_return(user)
        allow(controller).to receive(:set_user_by_token).and_return(controller.instance_eval { @resource = resource})
        response = get :validate_token, params: { cacheBuster: 2434234 }, format: :json
        result = JSON.parse response.body
        expect(result['id']).to eq(user.id)
      end
  
      it "should not validate token" do
        allow(controller).to receive(:set_user_by_token).and_return(controller.instance_eval { @resource = nil})
        response = get :validate_token, params: { cacheBuster: 2434234 }, format: :json
        result = JSON.parse response.body
        expect(result['errors'][0]['status']).to eq("401")
      end
    end
  end

end
