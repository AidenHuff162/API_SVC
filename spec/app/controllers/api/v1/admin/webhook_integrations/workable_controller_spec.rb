require 'rails_helper'

RSpec.describe Api::V1::Admin::WebhookIntegrations::WorkableController, type: :controller do
  let(:company) { create(:company, subdomain: 'workable') }

  describe 'get #workable_authorize' do
    context 'it should return true if current company is not present' do
      it 'should return ok status and true' do
        post :workable_authorize, format: :json
        expect(response.status).to eq(200)
        expect(response.body).to eq("true")
      end
    end

    context 'it should return true if current company is present' do
      it 'should return ok status and true' do
        allow(controller).to receive(:current_company).and_return(company)
        allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })
        post :workable_authorize, format: :json
        expect(response.status).to eq(200)
        expect(response.body).to eq("true")
      end
    end
  end

  describe 'get #subscribe' do
    context 'it should not subscribe to workable' do
      it 'should return Not found status if current company is not present' do
        get :subscribe, format: :json
        expect(response.status).to eq(404)
        expect(response.message).to eq("Not Found")
      end

      it 'should return nil id if integration is not present' do
        allow(controller).to receive(:current_company).and_return(company)
        allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })

        get :subscribe, format: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["id"]).to eq(nil)
      end

      it 'should return nil id if integration is present but access token is nil' do
        allow(controller).to receive(:current_company).and_return(company)
        allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })
        create(:workable, access_token: nil, company: company)

        get :subscribe, format: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["id"]).to eq(nil)
      end
    end

    context 'it should subscribe to workable' do
      it 'should return workable subscription_id' do
        allow(controller).to receive(:current_company).and_return(company)
        allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })
        allow_any_instance_of(AtsIntegrations::Workable).to receive(:subscribe).and_return(1)
        create(:workable_integration, company: company)

        get :subscribe, format: :json
        expect(JSON.parse(response.body)["id"]).to eq(1)
      end
    end
  end

  describe 'get #unsubscribe' do
    context 'it should not unsubscribe to workable' do
      it 'should return Not found status if current company is not present' do
        get :unsubscribe, format: :json
        expect(response.status).to eq(404)
        expect(response.message).to eq("Not Found")
      end

      it 'should return workable subscription_id id if integration is present but access token is nil' do
        allow(controller).to receive(:current_company).and_return(company)
        allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })
        workable = create(:workable_integration, company: company)
        workable.integration_credentials.find_by(name: 'Access Token').update(value: nil)

        get :unsubscribe, format: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["id"]).to eq(workable.subscription_id)
      end
    end

    context 'it should unsubscribe to workable' do
      it 'should return workable subscription_id' do
        allow(controller).to receive(:current_company).and_return(company)
        allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })
        allow_any_instance_of(AtsIntegrations::Workable).to receive(:unsubscribe).and_return(true)
        workable = create(:workable_integration, company: company)

        get :unsubscribe, format: :json
        expect(JSON.parse(response.body)["id"]).to eq(workable.subscription_id)
      end
    end
  end

  describe 'post #create' do
    context 'it should not create workable' do
      it 'should return Not found status if current company is not present' do
        post :create, format: :json
        expect(response.status).to eq(404)
        expect(response.message).to eq("Not Found")
      end
    end
    context 'it should create workable' do
      it 'should return true' do
      allow(controller).to receive(:current_company).and_return(company)
      allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })

      request.headers.merge! HTTP_X_WORKABLE_SIGNATURE: true
      post :create, format: :json
      expect(response.body).to eq('true')
      end
    end
  end
end
