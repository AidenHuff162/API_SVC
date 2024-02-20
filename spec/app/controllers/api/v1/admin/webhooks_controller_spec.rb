require 'rails_helper'

RSpec.describe Api::V1::Admin::WebhooksController, type: :controller do

  let(:company){ create(:company) }
  let(:user) { create(:user, company: company) }
  let(:webhook) { create(:webhook, company: company) }

  let(:company2){ create(:company) }
  let(:user2) { create(:user, company: company2) }

  before do
    WebMock.disable_net_connect!
    allow(controller).to receive(:current_company).and_return(company)
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe "GET #receive_test_event" do
    it "should create logging if receive_test_event trigerred" do
      get :receive_test_event, format: :json
      expect(company.loggings.where(action: 'Testing Webhook Event').present?).to eq(true)
    end
  end

  describe "GET #paginated" do
    context 'should not paginated data' do
      it "should return unauthorised status if user is not present" do
        allow(controller).to receive(:current_user).and_return(nil)
        get :paginated, format: :json
        expect(response.status).to eq(401)
      end

      it "should return Forbidden status if user is of other company" do
        allow(controller).to receive(:current_user).and_return(user2)
        get :paginated, format: :json
        expect(response.status).to eq(403)
      end
    end
    
    context 'should get paginated records' do
      it "should return test response" do
        webhook.save
        get :paginated, params: { start: 0, length: 5, order: { '0': {column: 1, dir: "asc"} }, search: {value: "" } }, format: :json
        expect(response.status).to eq(200)

        result = JSON.parse(response.body)
        expect(result['recordsTotal']).to eq(1)
        expect(result['data'][0].keys.count).to eq(9)
        expect(result['data'][0].keys).to eq(["id", "get_event", "target_url", "applies_to", "last_triggered_at", "get_state", "created", "description", "configurables"])
      end
    end
  end


  describe "POST #create" do
    context 'should not create webhooks' do
      it "should return unauthorised status if user is not present" do
        allow(controller).to receive(:current_user).and_return(nil)
        post :create, params: { state: :active, event: :stage_completed, target_url: 'http://company.domain/api/v1/admin/webhooks', description: Faker::Hipster.sentence, created_by_id: user.id}, format: :json
        expect(response.status).to eq(401)
      end

      it "should return Forbidden status if user is of other company" do
        allow(controller).to receive(:current_user).and_return(user2)
        post :create, params: { state: :active, event: :stage_completed, target_url: 'http://company.domain/api/v1/admin/webhooks', description: Faker::Hipster.sentence, created_by_id: user.id}, format: :json
        expect(response.status).to eq(403)
      end
    end

    context 'should create webhooks' do
      it "should create webhook for the company" do
        post :create, params: { state: :active, event: :stage_completed, target_url: 'http://company.domain/api/v1/admin/webhooks', description: Faker::Hipster.sentence, created_by_id: user.id}, format: :json
        expect(response.status).to eq(201)
        expect(response.message).to eq("Created")
        expect(company.webhooks.find_by_id(JSON.parse(response.body)['id']).present?).to eq(true)
      end
    end
  end

  describe "PUT #update" do
    context 'should not update webhooks' do
      it "should return unauthorised status if user is not present" do
        allow(controller).to receive(:current_user).and_return(nil)
        put :update, params: { id: webhook.id, event: :job_details_changed}, format: :json
        expect(response.status).to eq(401)
      end

      it "should return Forbidden status if user is of other company" do
        allow(controller).to receive(:current_user).and_return(user2)
        put :update, params: { id: webhook.id, event: :job_details_changed}, format: :json
        expect(response.status).to eq(403)
      end
    end
    
    context 'should update webhooks' do
      it "should update event of the webhook" do
        put :update, params: { id: webhook.id, event: :job_details_changed}, format: :json
        expect(response.status).to eq(200)
        expect(response.message).to eq('OK')
        expect(company.webhooks.find_by_id(JSON.parse(response.body)['id']).event).to eq('job_details_changed')
      end
    end
  end

  describe "DELETE #destroy" do
    context 'should not destroy webhooks' do
      it "should return unauthorised status if user is not present" do
        allow(controller).to receive(:current_user).and_return(nil)
        delete :destroy, params: { id: webhook.id }, format: :json
        expect(response.status).to eq(401)
      end

      it "should return Forbidden status if user is of other company" do
        allow(controller).to receive(:current_user).and_return(user2)
        delete :destroy, params: { id: webhook.id }, format: :json
        expect(response.status).to eq(403)
      end
    end
    
    context 'should destroy webhooks' do
      it "should destroy webhook" do
        delete :destroy, params: { id: webhook.id }, format: :json
        expect(response.status).to eq(204)
        expect(company.webhooks.find_by_id(webhook.id).present?).to eq(false)
      end
    end
  end

  describe "GET #show" do
    context 'should not get webhook' do
      it "should return unauthorised status if user is not present" do
        allow(controller).to receive(:current_user).and_return(nil)
        get :show, params: { id: webhook.id }, format: :json
        expect(response.status).to eq(401)
      end

      it "should return Forbidden status if user is of other company" do
        allow(controller).to receive(:current_user).and_return(user2)
        get :show, params: { id: webhook.id }, format: :json
        expect(response.status).to eq(403)
      end
    end
    
    context 'should get webhook' do
      it "should return webhook" do
        get :show, params: { id: webhook.id }, format: :json
        result = JSON.parse(response.body)
        expect(response.status).to eq(200)
        expect(result.keys).to eq(["id", "event", "target_url", "configurable", "filters", "description", "webhook_key", "zapier"])
        expect(result.keys.count).to eq(8)
      end
    end
  end
  
  describe "PUT #test_event" do
    context 'should not generate test event' do
      it "should return unauthorised status if user is not present" do
        allow(controller).to receive(:current_user).and_return(nil)
        put :test_event, params: { id: webhook.id }, format: :json
        expect(response.status).to eq(401)
      end

      it "should return Forbidden status if user is of other company" do
        allow(controller).to receive(:current_user).and_return(user2)
        put :test_event, params: { id: webhook.id }, format: :json
        expect(response.status).to eq(403)
      end
    end
    
    context 'should generate test event' do
      it "should return webhook" do
        put :test_event, params: { id: webhook.id }, format: :json
        expect(response.status).to eq(204)
        expect(webhook.webhook_events.where(is_test_event: true).present?).to eq(true)
      end
    end
  end

  describe "POST #new_test_event" do
    context 'should not generate new test event' do
      it "should return unauthorised status if user is not present" do
        allow(controller).to receive(:current_user).and_return(nil)
        post :new_test_event, params: { event: :stage_completed, target_url: 'http://company.domain/api/v1/admin/webhooks' }, format: :json
        expect(response.status).to eq(401)
      end

      it "should return Forbidden status if user is of other company" do
        allow(controller).to receive(:current_user).and_return(user2)
        post :new_test_event, params: { event: :stage_completed, target_url: 'http://company.domain/api/v1/admin/webhooks' }, format: :json
        expect(response.status).to eq(403)
      end
    end
    
    context 'should generate new test event' do
      it "should return test response" do
        stub_request(:post, 'http://company.domain/api/v1/admin/webhooks').
        with(
          body: "{\"data\":\"testing webhook endpoint while creation\",\"test_request\":true}",
          headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type'=>'application/json',
          'User-Agent'=>'Faraday v0.17.6'
          }).to_return(status: 200, body: "", headers: {})

        post :new_test_event, params: { event: :stage_completed, target_url: 'http://company.domain/api/v1/admin/webhooks' }, format: :json
        expect(response.status).to eq(201)
        result = JSON.parse(response.body)
        expect(result.keys.count).to eq(4)
        expect(result.keys).to eq(["created_at", "event_id", "status", "response_body"])
      end
    end
  end

  describe "PUT #subscribe_zap" do
    context 'should not subscribe to zap' do
      it "should return 404 if current_company is not present" do
        allow(controller).to receive(:current_company).and_return(nil)
        put :subscribe_zap, params: { ket: 'test' }, format: :json
        expect(response.status).to eq(404)
      end

      it "should return 404 status code if webhook not found" do
        allow_any_instance_of(WebhookServices::ZapierService).to receive(:subscribe).and_return({code: 404})
        put :subscribe_zap, params: { ket: 'test' }, format: :json
        expect(response.status).to eq(404)
        expect(JSON.parse(response.body)['errors'][0]['details']).to eq('End-Point Not Found.')
      end

      it "should return 400 status code if webhook already exists" do
        allow_any_instance_of(WebhookServices::ZapierService).to receive(:subscribe).and_return({code: 400})
        put :subscribe_zap, params: { ket: 'test' }, format: :json
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)['errors'][0]['details']).to eq('Already Exists')
      end
    end
    
    context 'should subscribe to zap' do
      it "should return 204 status code " do
        allow_any_instance_of(WebhookServices::ZapierService).to receive(:subscribe).and_return({code: 204})
        put :subscribe_zap, params: { ket: 'test' }, format: :json
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['status']['code']).to eq(204)
      end
    end
  end

  describe "delete #unsubscribe_zap" do
    context 'should not subscribe to zap' do
      it "should return 404 if current_company is not present" do
        allow(controller).to receive(:current_company).and_return(nil)
        delete :unsubscribe_zap, params: { ket: 'test' }, format: :json
        expect(response.status).to eq(404)
      end

      it "should return 404 status code if webhook not found" do
        allow_any_instance_of(WebhookServices::ZapierService).to receive(:unsubscribe).and_return({code: 404})
        delete :unsubscribe_zap, params: { ket: 'test' }, format: :json
        expect(response.status).to eq(404)
        expect(JSON.parse(response.body)['errors'][0]['details']).to eq('End-Point Not Found')
      end
    end
    
    context 'should subscribe to zap' do
      it "should return 204 status code " do
        allow_any_instance_of(WebhookServices::ZapierService).to receive(:unsubscribe).and_return({code: 204})
        delete :unsubscribe_zap, params: { ket: 'test' }, format: :json
        expect(response.status).to eq(204)
      end
    end
  end

  describe "get #authenticate_zap" do
    context 'should not authenticate to zap' do
      it "should return 404 if current_company is not present" do
        allow(controller).to receive(:current_company).and_return(nil)
        get :authenticate_zap, params: { ket: 'test' }, format: :json
        expect(response.status).to eq(404)
      end

      it "should return 401 status code if webhook not found" do
        allow_any_instance_of(WebhookServices::ZapierService).to receive(:authenticate).and_return(false)
        get :authenticate_zap, params: { ket: 'test' }, format: :json
        expect(response.status).to eq(401)
      end
    end
    
    context 'should authenticate to zap' do
      it "should return 200 status code " do
        allow_any_instance_of(WebhookServices::ZapierService).to receive(:authenticate).and_return(true)
        get :authenticate_zap, params: { ket: 'test' }, format: :json
        expect(response.status).to eq(200)
      end
    end
  end

  describe "get #generate_zap_key" do
    context 'should not generate zap keys' do
      it "should return unauthorised status if user is not present" do
        allow(controller).to receive(:current_user).and_return(nil)
        get :generate_zap_key, format: :json
        expect(response.status).to eq(401)
      end

      it "should return Forbidden status if user is of other company" do
        allow(controller).to receive(:current_user).and_return(user2)
        get :generate_zap_key, format: :json
        expect(response.status).to eq(403)
      end
    end
    
    context 'should generate zap key' do
      it "should return 200 status code " do
        get :generate_zap_key, format: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['token'].present?).to eq(true)
      end
    end
  end

  describe "get #perform_list_zap" do
    context 'should not get perform list zap' do
      it "should return 404 if current_company is not present" do
        allow(controller).to receive(:current_company).and_return(nil)
        get :perform_list_zap, format: :json
        expect(response.status).to eq(404)
      end
    end
    
    context 'should not get perform list zap' do
      it "should return 200 status code " do
        allow_any_instance_of(WebhookServices::ZapierService).to receive(:perform_list_zap).and_return(true)
        get :perform_list_zap, format: :json
        expect(response.status).to eq(200)
      end
    end
  end
  

end
