require 'rails_helper'

RSpec.describe Api::V1::WorkspacesController, type: :controller do

	let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:valid_session) { {} }
  let(:workspace_image) { create(:workspace_image) }
  let(:workspace) { create(:workspace_with_multiple_members, company: company, workspace_image: workspace_image) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "GET #show" do
  	context "should show workspace" do
  		before do
        get :show, params: { id: workspace.id }, format: :json
        @result = JSON.parse(response.body)
      end

  		it "should return 200 status" do
  			expect(response.status).to eq(200)
      end

      it "should return necessary keys count of workspace" do
        expect(@result.keys.count).to eq(9)
      end

      it "should return necessary keys of workspace" do
        expect(@result.keys).to eq(["id", "name", "workspace_role", "workspace_image_id", "time_zone", "notification_all", "notification_ids", "associated_email", "workspace_image"])
      end

      it "should return necessary keys count of workspace image" do
        expect(@result['workspace_image'].keys.count).to eq(2)
      end

      it "should return necessary keys name of workspace image" do
        expect(@result['workspace_image'].keys).to eq(["id", "image"])
      end
  	end

    context "should not show workspace for unauthenticated user" do
      it "should return unauthorized status" do
        allow(controller).to receive(:current_user).and_return(nil)
        get :show, params: { id: workspace.id }, format: :json
        expect(response.status).to eq(401)
      end
    end

  	context "should not show workspace of other company" do
  		let(:other_company) { create(:company, subdomain: 'boo') }
  		let(:other_workspace) { create(:workspace_with_multiple_members, company: other_company, workspace_image: workspace_image) }

  		before do
        get :show, params: { id: other_workspace.id }, format: :json
        @result = JSON.parse(response.body)
      end

  		it "should return forbidden status" do
  			expect(response.status).to eq(403)
      end
  	end

  	context "should return workspace role on the basis of current user role" do
  		it "should return admin as member role for current user of account owner role" do
  			allow(controller).to receive(:current_user).and_return(workspace.members.where(role: User.roles[:account_owner]).take)
		    allow(controller).to receive(:current_company).and_return(workspace.members.where(role: User.roles[:account_owner]).take.company)

  			get :show, params: { id: workspace.id }, format: :json

        result = JSON.parse(response.body)
        expect(result['workspace_role']).to eq('admin')
  		end

  		it "should return user as member role for current user of employee role" do
  			allow(controller).to receive(:current_user).and_return(workspace.members.where(role: User.roles[:employee]).take)
			  allow(controller).to receive(:current_company).and_return(workspace.members.where(role: User.roles[:employee]).take.company)

  			get :show, params: { id: workspace.id }, format: :json

        result = JSON.parse(response.body)
        expect(result['workspace_role']).to eq('user')
  		end
  	end
  end

  describe "GET #basic" do
  	context "should show workspace" do
  		before do
        get :basic, params: { id: workspace.id }, format: :json
        @result = JSON.parse(response.body)
      end

  		it "should return 200 status" do
  			expect(response.status).to eq(200)
      end

      it "should return necessary keys count of workspace" do
        expect(@result.keys.count).to eq(4)
      end

      it "should return necessary keys of workspace" do
        expect(@result.keys).to eq(["id", "name", "workspace_role", "workspace_image"])
      end

      it "should return necessary keys count of workspace image" do
        expect(@result['workspace_image'].keys.count).to eq(2)
      end

      it "should return necessary keys name of workspace image" do
        expect(@result['workspace_image'].keys).to eq(["id", "image"])
      end
  	end

  	context "should not show workspace of other company" do
  		let(:other_company) { create(:company, subdomain: 'boo') }
  		let(:other_workspace) { create(:workspace_with_multiple_members, company: other_company, workspace_image: workspace_image) }

  		before do
        get :basic, params: { id: other_workspace.id }, format: :json
        @result = JSON.parse(response.body)
      end

  		it "should return forbidden status" do
  			expect(response.status).to eq(403)
      end
  	end

  	context "should return workspace role on the basis of current user role" do
  		it "should return admin as member role for current user of account owner role" do
  			allow(controller).to receive(:current_user).and_return(workspace.members.where(role: User.roles[:account_owner]).take)
		    allow(controller).to receive(:current_company).and_return(workspace.members.where(role: User.roles[:account_owner]).take.company)

  			get :basic, params: { id: workspace.id }, format: :json

        result = JSON.parse(response.body)
        expect(result['workspace_role']).to eq('admin')
  		end

  		it "should return user as member role for current user of employee role" do
  			allow(controller).to receive(:current_user).and_return(workspace.members.where(role: User.roles[:employee]).take)
			  allow(controller).to receive(:current_company).and_return(workspace.members.where(role: User.roles[:employee]).take.company)

  			get :basic, params: { id: workspace.id }, format: :json

        result = JSON.parse(response.body)
        expect(result['workspace_role']).to eq('user')
  		end
  	end

    context "should not show workspace for unauthenticated user" do
      it "should return unauthorized status" do
        allow(controller).to receive(:current_user).and_return(nil)
        get :basic, params: { id: workspace.id }, format: :json
        expect(response.status).to eq(401)
      end
    end
  end

  describe "PUT #update" do
  	context "should update workspace" do
	  	let(:workspace_image2) { create(:workspace_image2) }

	  	before do
	  		put :update, params: { id: workspace.id, name: 'Workspace Sample', associated_email: 'testing@sapling.com', workspace_image_id: workspace_image2.id }, format: :json
	  		@result = JSON.parse(response.body)
	  	end

	  	it "should return ok status" do
	  		expect(response.status).to eq(200)
	  	end

	  	it "should update name as workspace sample" do
	  		expect(@result['name']).to eq('Workspace Sample')
	  	end

	  	it "should update associated email as testing@sapling.com" do
	  		expect(@result['associated_email']).to eq('testing@sapling.com')
	  	end

	  	it "should update workspace image id as latest id" do
	  		expect(@result['workspace_image_id']).to eq(workspace_image2.id)
	  	end

	  	it "should return necessary keys count of workspace" do
	      expect(@result.keys.count).to eq(9)
	    end

	    it "should return necessary keys of workspace" do
	      expect(@result.keys).to eq(["id", "name", "workspace_role", "workspace_image_id", "time_zone", "notification_all", "notification_ids", "associated_email", "workspace_image"])
	    end

	    it "should return necessary keys count of workspace image" do
	      expect(@result['workspace_image'].keys.count).to eq(2)
	    end

	    it "should return necessary keys name of workspace image" do
	      expect(@result['workspace_image'].keys).to eq(["id", "image"])
	    end
	  end

	  context "should not update workspace of other company" do
	  	let(:workspace_image2) { create(:workspace_image2) }
	  	let(:other_company) { create(:company, subdomain: 'boo') }
	  	let(:other_workspace) { create(:workspace_with_multiple_members, company: other_company, workspace_image: workspace_image) }

	  	before do
	  		put :update, params: { id: other_workspace.id, name: 'Workspace Sample', associated_email: 'testing@sapling.com', workspace_image_id: workspace_image2.id }, format: :json
	  	end

	  	it "should return forbidden status" do
	  		expect(response.status).to eq(403)
	  	end
	  end

    context "should not update workspace for unauthenticated user" do
      it "should return unauthorized status" do
        allow(controller).to receive(:current_user).and_return(nil)
        put :update, params: { id: workspace.id, name: 'Workspace Sample', associated_email: 'testing@sapling.com' }, format: :json
        expect(response.status).to eq(401)
      end
    end
  end

  describe "DELETE #destroy" do
    context "should delete workspace" do

      it "should return no content status" do
        delete :destroy, params: { id: workspace.id }, format: :json
        expect(response.status).to eq(204)
      end

      it "should return no workspace" do
        delete :destroy, params: { id: workspace.id }, format: :json
        expect(company.workspaces.count).to eq(0)
      end
    end

    context "should not delete workspace of other company" do
      let(:other_company) { create(:company, subdomain: 'boo') }
      let(:other_workspace) { create(:workspace_with_multiple_members, company: other_company, workspace_image: workspace_image) }

      it "should return forbidden status" do
        delete :destroy, params: { id: other_workspace.id }, format: :json
        expect(response.status).to eq(403)
      end
    end

    context "should not delete workspace for unauthenticated user" do
      it "should return unauthorized status" do
        allow(controller).to receive(:current_user).and_return(nil)
        delete :destroy, params: { id: workspace.id }, format: :json
        expect(response.status).to eq(401)
      end
    end
  end
end
