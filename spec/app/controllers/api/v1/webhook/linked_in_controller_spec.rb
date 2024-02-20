require 'rails_helper'

RSpec.describe Api::V1::Webhook::LinkedInController, type: :controller do
  let(:company) { create(:company, subdomain: 'lniked_in') }
  let!(:linked_in_integration) { create(:linkedin_integration, company: company) }

  before do
    allow(controller).to receive(:fetch_company).and_return(company)
    allow(controller).to receive(:fetch_company).and_return(controller.instance_eval {@current_company = fetch_company })
    allow_any_instance_of(AtsIntegrationsService::LinkedIn).to receive(:disable_extension).and_return(true)
  end

  describe 'GET #onboard' do
    before do
      allow_any_instance_of(AtsIntegrationsService::LinkedIn).to receive(:validate_onboarding_signature).and_return(true)
    end

    context 'should not onboard' do
      context 'if current company is not present' do
        it "should return unauthorized status" do
          allow(controller).to receive(:fetch_company).and_return(nil)
          get :onboard, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'if linked in integration is not present' do
        it "should return unauthorized status" do
          linked_in_integration.destroy
          get :onboard, params: { hiringContext: linked_in_integration.hiring_context }, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    # context 'should onboard user' do
    #   it 'should redirect user' do
    #     get :onboard, format: :json
    #     expect(response.status).to eq(302)
    #     expect(response.redirect_url).to eq("http://lniked_in.frontend.me:8080/#/admin/settings/integrations?source=linked_in&redirect_url=&map=linkedin")
    #   end
    # end
  end

  describe 'POST #callback' do
    before do
      allow_any_instance_of(AtsIntegrationsService::LinkedIn).to receive(:manage_pending_hire).and_return(true)
    end

    context 'should not callback' do
      context 'if current company is not present' do
        it "should return unauthorized status" do
          allow(controller).to receive(:fetch_company).and_return(nil)
          post :callback, params: { type: 'CREATE_THIRD_PARTY_HRIS_EXPORT_PROFILE_REQUEST', hrisRequestId: 'abc' }, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'if linked in integration is not present' do
        it "should return unauthorized status" do
          linked_in_integration.destroy
          post :callback, params: { type: 'CREATE_THIRD_PARTY_HRIS_EXPORT_PROFILE_REQUEST', hrisRequestId: 'abc' }, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      # context 'if required fields are not present' do
      #   it 'should return unauthorized status if hrisRequestId is not present' do
      #     post :callback, params: { type: 'CREATE_THIRD_PARTY_HRIS_EXPORT_PROFILE_REQUEST' }, format: :json
      #     expect(response).to have_http_status(:bad_request)
      #     expect(JSON.parse(response.body)["errorMessage"]).to eq('Required Fields are missing from payload.')
      #   end

      #   it 'should return unauthorized status if type is not present' do
      #     post :callback, params: { hrisRequestId: 'abc' }, format: :json
      #     expect(response).to have_http_status(:bad_request)
      #     expect(JSON.parse(response.body)["errorMessage"]).to eq('Required Fields are missing from payload.')
      #   end

      #   it 'should return unauthorized status if type is invalid' do
      #     post :callback, params: { type: 'abc', hrisRequestId: 'abc' }, format: :json
      #     expect(response).to have_http_status(:bad_request)
      #     expect(JSON.parse(response.body)["errorMessage"]).to eq('Required Fields are missing from payload.')
      #   end
      # end
    end

    # context 'should successfully create pending hire' do
    #   it 'should return ok status' do
    #     post :callback, params: { type: 'CREATE_THIRD_PARTY_HRIS_EXPORT_PROFILE_REQUEST', hrisRequestId: 'abc' }, format: :json
    #       expect(response).to have_http_status(:success)
    #   end
    # end
  end
end
