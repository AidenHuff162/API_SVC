require 'rails_helper'

RSpec.describe Api::V1::Admin::OnboardingIntegrations::BambooController, type: :controller do
  let(:company) { create(:company, subdomain: 'bamboo') }
  let(:super_admin) { create(:user, company: company) }

  before do
    allow(controller).to receive(:current_user).and_return(super_admin)
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe 'get #job_title_index' do
    context "should not return job title" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        get :job_title_index, format: :json
        expect(response.status).to eq(401)
      end

      it "should return not found status if current_company is not present" do
        allow(controller).to receive(:current_company).and_return(nil)
        get :job_title_index, format: :json
        expect(response.status).to eq(404)
      end
    end
    
    context "should return job title" do
      it 'should return ok status, Job titles' do 
        expect_any_instance_of(::HrisIntegrationsService::Bamboo::JobTitle).to receive(:fetch) { ['title1', 'title2'] }
        get :job_title_index, format: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body).count).to eq(2)
        expect(JSON.parse(response.body)).to eq(['title1', 'title2'])
      end
    end
  end

  describe 'post #create_job_title' do
    context "should not create job title" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        post :create_job_title, format: :json
        expect(response.status).to eq(401)
      end

      it "should return not found status if current_company is not present" do
        allow(controller).to receive(:current_company).and_return(nil)
        post :create_job_title, format: :json
        expect(response.status).to eq(404)
      end
    end
    
    context "should create job title" do
      before do
        @bamboo_queue = Sidekiq::Queues["update_departments_and_locations"].size
        post :create_job_title, params: {title: 'title'}, format: :json
      end

      it 'should return ok status' do 
        expect(response.status).to eq(200)
      end
      it 'should return false' do 
        expect(response.body).to eq('false')
      end
      it 'should increment bamboo queue' do
        expect(Sidekiq::Queues["update_departments_and_locations"].size).to eq(@bamboo_queue + 1)
      end 
    end
  end

  describe 'post #create' do
    context "should not update sapling user from bamboo job" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        post :create, format: :json
        expect(response.status).to eq(401)
      end

      it "should return not found status if current_company is not present" do
        allow(controller).to receive(:current_company).and_return(nil)
        post :create, format: :json
        expect(response.status).to eq(404)
      end
    end
    
    context "should UpdateSaplingUsersFromBambooJob" do
      before do
        @bamboo_queue = Sidekiq::Queues["receive_employee_from_hr"].size
        post :create, params: {title: 'title'}, format: :json
      end

      it 'should return ok status' do 
        expect(response.status).to eq(200)
      end
      it 'should return false' do 
        expect(response.body).to eq('false')
      end
      it 'should increment bamboo queue' do
        expect(Sidekiq::Queues["receive_employee_from_hr"].size).to eq(@bamboo_queue + 1)
      end 
    end
  end
end
