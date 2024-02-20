require 'rails_helper'

RSpec.describe Api::V1::Admin::GeneralDataProtectionRegulationsController, type: :controller do
  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:valid_session) { {} }
  let(:gdpr) { create(:general_data_protection_regulation, edited_by_id: user.id, company: company) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "POST #create" do
    context "should create GDPR" do
      it "should return created status" do
        post :create, params: { action_type: GeneralDataProtectionRegulation.action_types[:remove] }, format: :json
        expect(response.status).to eq(201)
      end
    end

    context "should not create 2 GDPR in a same company" do
      it "should return unprocessable entity status" do
        create(:general_data_protection_regulation, edited_by_id: user.id, company: company)
        post :create, params: { action_type: GeneralDataProtectionRegulation.action_types[:remove] }, format: :json
        expect(response.status).to eq(422)
      end
    end

    context "should not create GDPR by unauthenticated user" do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
      end

      it "should return unauthorized status" do
        post :create, params: { action_type: GeneralDataProtectionRegulation.action_types[:remove] }, format: :json
        expect(response.status).to eq(401)
      end
    end

    context "should not create GDPR by other company's user" do
      before do
        other_user = create(:user, state: :active, current_stage: :registered, company: create(:company, subdomain: 'boo'))
        allow(controller).to receive(:current_user).and_return(other_user)
      end

      it "should return forbidden status" do
        post :create, params: { action_type: GeneralDataProtectionRegulation.action_types[:remove] }, format: :json
        expect(response.status).to eq(403)
      end
    end

    context "should not create GDPR by non admin user" do
      before do
        employee = create(:user, state: :active, current_stage: :registered, company: company, role: User.roles[:employee])
        allow(controller).to receive(:current_user).and_return(employee)
      end

      it "should return forbidden status" do
        post :create, params: { action_type: GeneralDataProtectionRegulation.action_types[:remove] }, format: :json
        expect(response.status).to eq(403)
      end
    end
  end

  describe "PUT #update" do
    context "should check update for authorised user" do
      it "should update the GDPR if action type exists" do
        put :update, params: { id: gdpr.id, action_type: GeneralDataProtectionRegulation.action_types[:remove] }, format: :json
        gdpr.reload
        expect(gdpr.action_type).to eq(GeneralDataProtectionRegulation.action_types.key(GeneralDataProtectionRegulation.action_types[:remove]))
      end

      it "should not update the GDPR if action type does not exits" do
        put :update, params: { id: gdpr.id, action_type: nil }, format: :json
        gdpr.reload
        expect(gdpr.action_type).to eq(GeneralDataProtectionRegulation.action_types.key(GeneralDataProtectionRegulation.action_types[:anonymize]))
      end

      it "should update the GDPR if action period exists" do
        put :update, params: { id: gdpr.id, action_period: 3 }, format: :json
        gdpr.reload
        expect(gdpr.action_period).to eq(3)
      end

      it "should not update the GDPR if action period does not exists" do
        put :update, params: { id: gdpr.id, action_period: nil }, format: :json
        gdpr.reload
        expect(gdpr.action_period).to eq(1)
      end

      it "should update the GDPR if edited by id exists" do
        put :update, params: { id: gdpr.id, edited_by_id: user.id }, format: :json
        gdpr.reload
        expect(gdpr.edited_by_id).to eq(user.id)
      end

      it "should not update the GDPR if edited by id does not exists" do
        put :update, params: { id: gdpr.id, edited_by_id: nil }, format: :json
        gdpr.reload
        expect(gdpr.edited_by_id).to eq(user.id)
      end
    end

    context "should not update GDPR by unauthenticated user" do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
      end

      it "should return unauthorized status" do
        put :update, params: { id: gdpr.id, action_period: 3 }, format: :json
        expect(response.status).to eq(401)
      end
    end

    context "should not update GDPR by other company's user" do
      before do
        other_user = create(:user, state: :active, current_stage: :registered, company: create(:company, subdomain: 'boo'))
        allow(controller).to receive(:current_user).and_return(other_user)
      end

      it "should return forbidden status" do
        put :update, params: { id: gdpr.id, action_period: 3 }, format: :json
        expect(response.status).to eq(403)
      end
    end

    context "should not update GDPR by non admin user" do
      before do
        employee = create(:user, state: :active, current_stage: :registered, company: company, role: User.roles[:employee])
        allow(controller).to receive(:current_user).and_return(employee)
      end

      it "should return forbidden status" do
        put :update, params: { id: gdpr.id, action_period: 3 }, format: :json
        expect(response.status).to eq(403)
      end
    end
  end

  describe "GET index" do
    context "should return GDPR index" do
      before do
        create(:general_data_protection_regulation, edited_by_id: user.id, company: company)
        get :index, format: :json
      end

      it "should return ok status" do
        expect(response.status).to eq(200)
      end

      it "should return necessary data" do
        expect(JSON.parse(response.body).keys).to eq(["id", "action_type", "action_period", "action_location", "edited_by", "updated_at", "applied_locations"])
      end
    end

    context "should not return GDPR index for unauthenticated user" do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        create(:general_data_protection_regulation, edited_by_id: user.id, company: company)
        get :index, format: :json
      end

      it "should return unauthorized status" do
        expect(response.status).to eq(401)
      end
    end

    context "should not return GDPR by non admin user" do
      before do
        employee = create(:user, state: :active, current_stage: :registered, company: company, role: User.roles[:employee])
        allow(controller).to receive(:current_user).and_return(employee)

        create(:general_data_protection_regulation, edited_by_id: user.id, company: company)
        get :index, format: :json
      end

      it "should return forbidden status" do
        expect(response.status).to eq(403)
      end
    end

    context "should not return GDPR by other company's user" do
      before do
        other_user = create(:user, state: :active, current_stage: :registered, company: create(:company, subdomain: 'boo'))
        allow(controller).to receive(:current_user).and_return(other_user)

        create(:general_data_protection_regulation, edited_by_id: user.id, company: company)
        get :index, format: :json
      end

      it "should return forbidden status" do
        expect(response.status).to eq(403)
      end
    end
  end
end
