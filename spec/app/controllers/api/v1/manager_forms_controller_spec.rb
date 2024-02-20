require 'rails_helper'

RSpec.describe Api::V1::ManagerFormsController, type: :controller do

  let(:user) { create(:tim) }
  let(:company) { create(:company) }

  describe 'GET #show' do
    context 'Unauthorized without login' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        allow(controller).to receive(:current_company).and_return(user.company)
      end
      it "It should return un-authorized if user not present" do
        get :show, params: { employee_id: user.id, id: 'show_manager_form', token: user.ensure_manager_form_token.to_s }
        expect(response.status).to eq(401)
      end
    end

    context 'Unauthorized without current_company' do
      before do
        allow(controller).to receive(:current_user).and_return(user)
        allow(controller).to receive(:current_company).and_return(nil)
      end
      it "It should return 404 not found if company not present" do
        get :show, params: { employee_id: user.id, id: 'show_manager_form', token: user.ensure_manager_form_token.to_s }
        expect(response.status).to eq(404)
      end
    end

    context 'User not allowed to access with other company' do
      before do
        allow(controller).to receive(:current_user).and_return(user)
        allow(controller).to receive(:current_company).and_return(company)
      end
      it "It should return forbidden exception" do
        get :show, params: { employee_id: user.id, id: 'show_manager_form', token: user.ensure_manager_form_token.to_s }
        expect(response.status).to eq(401)
        expect(JSON.parse(response.body)["error"]).to eq('Unauthorized Access')
      end
    end

    context 'Should allow to access' do
      before do
        allow(controller).to receive(:current_user).and_return(user)
        allow(controller).to receive(:current_company).and_return(user.company)
      end
      it "Only for current logged in user" do
        get :show, params: { employee_id: user.managed_users.ids.first, id: 'show_manager_form', token: user.ensure_manager_form_token.to_s }
        expect(response.status).to eq(204)
      end

      it "initialize resource instance" do
        get :show, params: { employee_id: user.managed_users.ids.first, id: 'show_manager_form', token: user.ensure_manager_form_token.to_s }
        expect(controller.instance_variable_get(:@resource).id).to eq(user.id)
      end
    end

  end
end
