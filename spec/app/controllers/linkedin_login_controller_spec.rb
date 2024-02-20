require 'rails_helper'

RSpec.describe LinkedinLoginController, type: :controller do
  let(:company) { create(:company, subdomain: 'welcome_foo') }
  let(:with_linkedin_integration) { create(:with_linkedin_integration, subdomain: 'welcome_fooo') }

  before do
    company.profile_templates.destroy_all
    ProfileTemplateCustomFieldConnection.with_deleted.where(profile_template_id: company.profile_templates.with_deleted.pluck(:id)).delete_all
    company.profile_templates.with_deleted.delete_all
  end

  describe "Get onboard" do
    it "It should redirect_to onboard" do
      get :onboard
      expect(response.status).to eq(200)
    end
  end

  describe "verify_domain" do
    it "It should verify_domain" do
      post :verify_domain
      expect(response.status).to eq(200)
    end

    it "It should verify_domain" do
      post :verify_domain, params: { object: {data: 'abc'} }, format: :json
      expect(response.status).to eq(200)
    end

    it "It should verify_domain" do
      post :verify_domain, params: { object: {data: 'abc'}, subdomain: company.subdomain }, format: :json
      expect(response.status).to eq(200)
    end

    it "It should verify_domain" do
      post :verify_domain, params: { object: {data: 'abc'}, subdomain: with_linkedin_integration.subdomain }, format: :json
      expect(response.status).to eq(200)
    end

    it "It should verify_domain" do
    	subdomain = company.subdomain
      post :verify_domain, params: { object: {data: 'abc'}, subdomain: subdomain }, format: :json
      expect(response.status).to eq(200)
    end
  end
end
