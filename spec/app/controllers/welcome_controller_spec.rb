require 'rails_helper'

RSpec.describe WelcomeController, type: :controller do
  let(:current_company) { create(:company, subdomain: 'welcome_foo') }
  let (:user) { create(:user) }
  let(:company) { user.company }

  describe "Get index" do

    context 'Without subdomain' do
      before do
        @request.host = "http://lv.me.com"
      end

      it "It should set subdomain instance variable" do
        get :index
        expect(controller.instance_variable_get(:@subdomain_exist)).to eq(false)
      end

      it "It should redirect_to saplinghr domain" do
        get :index
        expect(response.status).to eq(302)
        expect(response).to redirect_to('https://www.trysapling.com/')
      end
    end
  end

  describe "Get check_subdomain" do
    context 'With subdomain' do
      before do
        @request.host = "#{current_company.domain}"
      end

      it "It should set subdomain instance variable" do
        get :check_subdomain
        expect(controller.instance_variable_get(:@subdomain_exist)).to eq(true)
      end

      it "It should return success status" do
        get :check_subdomain
        expect(response.status).to eq(200)
      end
    end

    context 'Without subdomain' do
      before do
        @request.host = "http://lv.me.com"
      end

      it "It should set subdomain instance variable" do
        get :check_subdomain
        expect(controller.instance_variable_get(:@subdomain_exist)).to eq(false)
      end

      it "It should return 404 status" do
        get :check_subdomain
        expect(JSON.parse(response.body)["status"]).to eq(404)
      end
    end
  end

  describe "Get get_orgchart" do
    context 'With subdomain' do
      before do
        @request.host = "#{company.domain}"
        company.update(organization_root_id: user.id, enabled_org_chart: true)
        company.generate_organization_tree
        company.generate_token
      end

      it "It should set subdomain instance variable" do
        get :get_orgchart, params: {token: 555}
        expect(controller.instance_variable_get(:@subdomain_exist)).to eq(true)
      end

      it "It should return organization chart data" do
        get :get_orgchart, params: {token: company.token}
        expect(JSON.parse(response.body)["org_root_present"]).to eq(true)
      end

      it "It should not return organization chart data witout token" do
        get :get_orgchart, params: {token: 88}
        expect(JSON.parse(response.body)["org_root_present"]).to eq(false)
      end
    end

    context 'Without enabled_org_chart' do
      before do
        @request.host = "#{company.domain}"
        company.generate_token
      end

      it "It should not return organization chart data" do
        get :get_orgchart, params: {token: company.token}
        expect(JSON.parse(response.body)["org_root_present"]).to eq(false)
      end
    end
  end
end
