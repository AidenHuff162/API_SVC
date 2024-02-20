require 'rails_helper'

RSpec.describe Api::V1::Admin::WorkspacesController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:member1) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:valid_session) { {} }
  let(:workspace_image) { create(:workspace_image) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "POST #create" do
    context "should not create workspace" do
      it "should not create workspace if name is not present" do
        post :create, params: { workspace_image_id: workspace_image.id }, format: :json
        expect(response.message).to eq('Unprocessable Entity')
      end

      it "should not create workspace if name and image is not present" do
        post :create, params: { associated_email: 'it@test.com' }, format: :json
        expect(response.message).to eq('Unprocessable Entity')
      end

      it "should not create workspace if image is not present" do
        post :create, params: { name: 'Workspace' }, format: :json
        expect(response.message).to eq('No Content')
      end
    end

    context "should create workspace without member" do
      it "should return created message" do
        post :create, params: { name: 'Workspace', workspace_image_id: workspace_image.id, company_id: company.id }, format: :json
        expect(response.message).to eq('Created')
      end
    end

    context "should create workspace with a user member" do
      before do
        post :create, params: { name: 'Workspace', workspace_image_id: workspace_image.id, company_id: company.id,
          workspace_members_ids: [{ member_role: 'user', member_id: member1.id }] }, format: :json
        @workspace = company.workspaces.find(JSON.parse(response.body)['id'])
      end

      it "should return created message" do
        expect(response.message).to eq('Created')
      end

      it "should check members count" do
        expect(@workspace.members.count).to eq(1)
      end

      it "should check workspace members count" do
        expect(@workspace.workspace_members.count).to eq(1)
      end

      it "should check workspace members role as user" do
        expect(@workspace.workspace_members.take.member_role).to eq('user')
      end
    end

    context "should create workspace with admin/user members" do
      before do
        post :create, params: { name: 'Workspace', workspace_image_id: workspace_image.id, company_id: company.id,
          workspace_members_ids: [{ member_role: 'user', member_id: member1.id }, { member_role: 'admin', member_id: user.id}] }, format: :json
        @workspace = company.workspaces.find(JSON.parse(response.body)['id'])
      end

      it "should return created message" do
        expect(response.message).to eq('Created')
      end

      it "should check members count" do
        expect(@workspace.members.count).to eq(2)
      end

      it "should check workspace members count" do
        expect(@workspace.workspace_members.count).to eq(2)
      end

      it "should check workspace members role as user" do
        expect(@workspace.workspace_members.find_by(member_id: member1.id).member_role).to eq('user')
      end

      it "should check workspace members role as admin" do
        expect(@workspace.workspace_members.find_by(member_id: user.id).member_role).to eq('admin')
      end
    end

    context "should not create workspace for unauthenticated user" do
      it "should return unauthorized status" do
        allow(controller).to receive(:current_user).and_return(nil)
        post :create, params: { name: 'Workspace', workspace_image_id: workspace_image.id, company_id: company.id,
          workspace_members_ids: [{ member_role: 'user', member_id: member1.id }, { member_role: 'admin', member_id: user.id}] }, format: :json
        expect(response.status).to eq(401)
      end
    end

    context "should not create workspace for employee type user" do
      let(:employee) { create(:user, state: :active, current_stage: :registered, company: company, role: User.roles[:employee]) }
      it "should return forbidden status" do
        allow(controller).to receive(:current_user).and_return(employee)
        post :create, params: { name: 'Workspace', workspace_image_id: workspace_image.id, company_id: company.id,
          workspace_members_ids: [{ member_role: 'user', member_id: member1.id }, { member_role: 'admin', member_id: user.id}] }, format: :json
        expect(response.status).to eq(403)
      end
    end
  end

  describe "GET #index" do
    context "should get the workspaces" do
      before do
        create(:workspace, company: user.company, workspace_image: workspace_image)
        create(:workspace, company: user.company, workspace_image: workspace_image)
        create(:workspace, company: create(:company, subdomain: 'boo'), workspace_image: workspace_image)

        get :index,  format: :json 
      end

      it "should return ok status" do
        expect(response.status).to eq(200)
      end

      it "should return workspaces of current company" do
        expect(JSON.parse(response.body).length).to eq(company.workspaces.length)
      end

      it "should only return necessary keys" do
        workspace = JSON.parse(response.body)[0]
        expect(workspace.keys).to eq(["id", "name", "workspace_role", "workspace_image"])
      end
    end

    context "should not get data for unauthenticated user" do
      it "should return unauthorized status" do
        allow(controller).to receive(:current_user).and_return(nil)
        get :index, format: :json
        expect(response.status).to eq(401)
      end
    end
  end
end
