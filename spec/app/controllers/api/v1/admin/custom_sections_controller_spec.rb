require 'rails_helper'

RSpec.describe Api::V1::Admin::CustomSectionsController, type: :controller do

  let(:company) { create(:company) }
  let(:super_admin) { create(:user, role: :account_owner, company: company) }
  let(:employee) { create(:user, role: :employee, company: company) }
  let(:manager) { create(:user, role: :employee, company: company) }
  let(:user) { create(:user, state: :active, current_stage: :invited, company: company) }
  let(:custom_section) { create(:custom_section, company: company) }
  let(:tim) { create(:tim, company: company) }
  
  before do
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe "GET #index" do
    context 'should show custom sections' do
      before do
        allow(controller).to receive(:current_user).and_return(user)
        get :index, format: :json
        @result = JSON.parse(response.body)
      end

      it 'should return 200 status, 6 keys for custom section and 5 keys for sub custom section' do
        custom_sections = @result
        expect(response.status).to eq(200)
        expect(custom_sections.present?).to eq(true)
        expect(custom_sections[0].keys.count).to eq(6)
        expect(custom_sections[0].keys).to eq(["section", "name", "help", "position", "custom_fields", "custom_section"])
        expect(custom_sections[0]['custom_section'].keys.count).to eq(6)
        expect(custom_sections[0]['custom_section'].keys).to eq(["id", "section", "is_approval_required", "approval_expiry_time", "approval_chains", "name"])
      end
    end

    context 'should not show custom sections for unauthenticated user' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        get :index, format: :json
      end

      it 'should return unauthorized status' do
        expect(response.status).to eq(401)
      end
    end

    context "should not return custom section for other company" do
      let(:other_company) { create(:company, subdomain: 'boo') }
      let(:other_user) { create(:user, company: other_company) }

      it 'should return forbidden status' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :index, format: :json
        expect(response.status).to eq(403)
      end
    end

    context 'employee should not have permission to get custom sections for index' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end

      it 'should return 403 status' do
        get :index, format: :json
        expect(response.status).to eq(403)
      end
    end

    context 'manager should not have permission to get custom sections for index' do
      before do
        employee.update!(manager_id: manager.id)
        manager.reload
        allow(controller).to receive(:current_user).and_return(manager)
      end

      it 'should return 403 status' do
        get :index, format: :json
        expect(response.status).to eq(403)
      end
    end
  end

  describe "PUT #update" do
    context 'should update custom section' do
      before do
        allow(controller).to receive(:current_user).and_return(super_admin)
        put :update, params: { id: custom_section.id, section: CustomSection.sections[:personal_info], is_approval_required: true, approval_chains_attributes: [{ approval_type: 'manager', approval_ids: ['1']}]}, as: :json
        @result = JSON.parse(response.body)
      end
      it "should return 200 status" do
        expect(response.status).to eq(200)
        expect(@result['section']).to eq("personal_info")
        expect(@result['is_approval_required']).to eq(true)
        expect(@result.keys.count).to eq(6)
        expect(@result.keys).to eq(["id", "section", "is_approval_required", "approval_expiry_time", "approval_chains", "name"])
      end
    end

    context 'should not update custom section for emplyee' do
      before do
        allow(controller).to receive(:current_user).and_return(tim)
        put :update, params: { id: custom_section.id, section: CustomSection.sections[:personal_info], is_approval_required: false, approval_expiry_time:nil, approval_chains_attributes: [{ approval_type: 'manager', approval_ids: ['1']}]}, as: :json
        @result = JSON.parse(response.body)
      end
      it "should return 403 status" do
        expect(response.status).to eq(403)
      end
    end

    context 'should not update custom section for emplyee' do
      before do
        employee.update!(manager_id: manager.id)
        manager.reload
        allow(controller).to receive(:current_user).and_return(manager)
        put :update, params: { id: custom_section.id, section: CustomSection.sections[:personal_info], is_approval_required: false, approval_expiry_time:nil, approval_chains_attributes: [{ approval_type: 'manager', approval_ids: ['1']}]}, as: :json
        @result = JSON.parse(response.body)
      end
      it "should return 403 status" do
        expect(response.status).to eq(403)
      end
    end
  end
end
