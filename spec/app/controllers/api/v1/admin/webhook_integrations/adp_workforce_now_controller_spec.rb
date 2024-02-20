require 'rails_helper'

RSpec.describe Api::V1::Admin::WebhookIntegrations::AdpWorkforceNowController, type: :controller do
  let!(:company) { create(:company, subdomain: 'adp_workforce_now') }
  let(:adp_us_integration) { create(:adp_wfn_us_integration, company: company) }
  let(:adp_can_integration) { create(:adp_wfn_can_integration, company: company, filters: {location_id: [''], team_id: ['all'], employee_type: ['all'] }) }

  before do
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe 'GET #job_titles_index' do
    
    context 'current company is not present' do
      it 'should return no job titles' do
        allow(controller).to receive(:current_company).and_return(nil)
        
        get :job_titles_index, format: :json
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([])
      end
    end

    context 'current company is present and using adp-usa integration only' do
      before do
        adp_us_integration

        create(:job_title, company: company)
        create(:adp_us_job_title, company: company)
        create(:adp_us_job_title, company: company)
        create(:adp_can_job_title, company: company)
      end

      it 'should return only adp-us job titles' do

        get :job_titles_index, format: :json
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body).count).to eq(2)
      end
    end

    context 'current company is present and using adp-can integration only' do
      before do
        adp_can_integration

        create(:job_title, company: company)
        create(:adp_us_job_title, company: company)
        create(:adp_us_job_title, company: company)
        create(:adp_can_job_title, company: company)
      end

      it 'should return only adp-can job titles' do

        get :job_titles_index, format: :json
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body).count).to eq(1)
      end
    end

    context 'current company is present and using adp-us/can integration only' do
      before do
        adp_us_integration
        adp_can_integration

        create(:job_title, company: company)
        create(:adp_us_job_title, company: company)
        create(:adp_us_job_title, company: company)
        create(:adp_can_job_title, company: company)
      end

      it 'should return only adp-us/can job titles' do

        get :job_titles_index, format: :json
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body).count).to eq(3)
      end
    end
  end
end