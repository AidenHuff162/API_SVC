require 'rails_helper'

RSpec.describe Api::V1::Admin::WorkspaceMembersController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:valid_session) { {} }
  let(:workspace_image) { create(:workspace_image) }
  let(:workspace_with_single_member) { create(:workspace_with_single_member, company: company, workspace_image: workspace_image) }
  let(:workspace_with_multiple_members) { create(:workspace_with_multiple_members, company: company, workspace_image: workspace_image) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "PUT #update" do
    context "should update workspace member role as admin" do
      before do
        @workspace_member = workspace_with_single_member.workspace_members.take
        put :update, params: { id: @workspace_member.id, member_role: WorkspaceMember.member_roles[:admin] }, as: :json
        @result = JSON.parse(response.body)
      end

      it "should return 200 status" do
        expect(response.status).to eq(200)
      end

      it "should match with workspace member id" do
        expect(@result['id']).to eq(@workspace_member.id)
      end

      it "should return member role as admin" do
        expect(@result['member_role']).to eq('admin')
      end

      it "should return member role name as Admin" do
        expect(@result['member_role_name']).to eq('Admin')
      end
    end

    context "should update workspace member role as user" do
      before do
        @workspace_member = workspace_with_multiple_members.workspace_members.find_by(member_role: WorkspaceMember.member_roles[:admin])
        put :update, params: { id: @workspace_member.id, member_role: WorkspaceMember.member_roles[:user] }, as: :json
        @result = JSON.parse(response.body)
      end

      it "should return ok status" do
        expect(response.status).to eq(200)
      end

      it "should match with workspace member id" do
        expect(@result['id']).to eq(@workspace_member.id)
      end

      it "should return member role as user" do
        expect(@result['member_role']).to eq('user')
      end

      it "should return member role name as User" do
        expect(@result['member_role_name']).to eq('User')
      end
    end

    context "should update workspace member and return necessary data" do
      before do
        @workspace_member = workspace_with_multiple_members.workspace_members.find_by(member_role: WorkspaceMember.member_roles[:admin])
        put :update, params: { id: @workspace_member.id, member_role: WorkspaceMember.member_roles[:user] }, as: :json
        @result = JSON.parse(response.body)
      end

      it "should return ok status" do
        expect(response.status).to eq(200)
      end

      it "should return necessary keys count of workspace members" do
        expect(@result.keys.count).to eq(4)
      end

      it "should return necessary keys of workspace members" do
        expect(@result.keys).to eq(["id", "member_role", "member_role_name", "member"])
      end

      it "should return workspace member as hash" do
        expect(@result['member'].class).to eq(Hash)
      end

      it "should return necessary keys count of workspace member" do
        expect(@result['member'].keys.count).to eq(22)
      end

      it "should return necessary keys name of workspace member" do
        expect(@result['member'].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name",
                                              "preferred_full_name", "is_reset_password_token_set", "is_password_set",
                                              "about_you", "provider", "display_name_format", "title", "location_name",
                                              "seen_profile_setup", "seen_documents_v2", "ui_switcher",
                                              "location", "open_tasks_count", "picture", "name", "manager", "display_name"])
      end
    end

    context "should not update workspace member of other company" do
      let(:other_company) { create(:company, subdomain: 'boo') }
      let(:workspace_of_other_company) { create(:workspace_with_single_member, company: other_company, workspace_image: workspace_image) }

      before do
        workspace_member = workspace_of_other_company.workspace_members.take
        put :update, params: { id: workspace_member.id, member_role: WorkspaceMember.member_roles[:admin] }, as: :json
      end

      it "should return forbidden status" do
        expect(response.status).to eq(403)
      end
    end

    context "should not update workspace member for unauthenticated user" do
      it "should return unauthorized status" do
        allow(controller).to receive(:current_user).and_return(nil)
        workspace_member = workspace_with_single_member.workspace_members.take
        put :update, params: { id: workspace_member.id, member_role: WorkspaceMember.member_roles[:admin] }, as: :json
        expect(response.status).to eq(401)
      end
    end
  end

  describe "DELETE #destroy" do
    context "should destroy workspace member of current company" do
      before do
        @workspace_member = workspace_with_multiple_members.workspace_members.find_by(member_role: WorkspaceMember.member_roles[:user])
        @workspace_members_count = workspace_with_multiple_members.workspace_members.count
        delete :destroy, params: { id: @workspace_member.id }, format: :json

        workspace_with_multiple_members.reload
      end

      it "should return no content status" do
        expect(response.status).to eq(204)
      end

      it "should check workspace members count" do
        expect(workspace_with_multiple_members.workspace_members.count).to eq((@workspace_members_count-1))
      end
    end

    context "should not destroy workspace member of other company" do
      let(:other_company) { create(:company, subdomain: 'boo') }
      let(:workspace_of_other_company) { create(:workspace_with_multiple_members, company: other_company, workspace_image: workspace_image) }

      before do
        @workspace_member = workspace_of_other_company.workspace_members.find_by(member_role: WorkspaceMember.member_roles[:user])
        @workspace_members_count = workspace_of_other_company.workspace_members.count
        delete :destroy, params: { id: @workspace_member.id }, format: :json

        workspace_of_other_company.reload
      end

      it "should return forbidden status" do
        expect(response.status).to eq(403)
      end

      it "should check workspace members count same as before" do
        expect(workspace_of_other_company.workspace_members.count).to eq(@workspace_members_count)
      end
    end

    context "should not destroy workspace member for unauthenticated user" do
      it "should return unauthorized status" do
        allow(controller).to receive(:current_user).and_return(nil)
        workspace_member = workspace_with_multiple_members.workspace_members.find_by(member_role: WorkspaceMember.member_roles[:user])
        delete :destroy, params: { id: workspace_member.id }, format: :json
        expect(response.status).to eq(401)
      end
    end
  end

  describe "POST #create" do
    context "should create workspace member as user and return necessary data" do
      let(:member) { create(:user, state: :active, current_stage: :registered, company: company) }

      before do
        post :create, params: { member_role: WorkspaceMember.member_roles[:user], member_id: member.id, workspace_id: workspace_with_multiple_members.id }, as: :json
        @result = JSON.parse(response.body)
      end

      it "should return created status" do
        expect(response.status).to eq(201)
      end

      it "should return member role name as User" do
        expect(@result['member_role_name']).to eq('User')
      end

      it "should return member role as user" do
        expect(@result['member_role']).to eq('user')
      end

      it "should return necessary keys count of workspace members" do
        expect(@result.keys.count).to eq(4)
      end

      it "should return necessary keys of workspace members" do
        expect(@result.keys).to eq(["id", "member_role", "member_role_name", "member"])
      end

      it "should return workspace member as hash" do
        expect(@result['member'].class).to eq(Hash)
      end

      it "should return necessary keys count of workspace member" do
        expect(@result['member'].keys.count).to eq(22)
      end

      it "should return necessary keys name of workspace member" do
        expect(@result['member'].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name",
                                              "preferred_full_name", "is_reset_password_token_set", "is_password_set",
                                              "about_you", "provider", "display_name_format", "title", "location_name",
                                              "seen_profile_setup", "seen_documents_v2", "ui_switcher",
                                              "location", "open_tasks_count", "picture", "name", "manager", "display_name"])
      end
    end

    context "should create workspace member as admin" do
      let(:member) { create(:user, state: :active, current_stage: :registered, company: company) }

      before do
        post :create, params: { member_id: member.id, workspace_id: workspace_with_multiple_members.id, member_role: WorkspaceMember.member_roles[:admin] }, as: :json
        @result = JSON.parse(response.body)
      end

      it "should return created status" do
        expect(response.status).to eq(201)
      end

      it "should return member role name as Admin" do
        expect(@result['member_role_name']).to eq('Admin')
      end

      it "should return member role as admin" do
        expect(@result['member_role']).to eq('admin')
      end
    end

    context "should not create workspace member in other company's workspace" do
      let(:other_company) { create(:company, subdomain: 'boo') }
      let(:member) { create(:user, state: :active, current_stage: :registered, company: other_company) }

      before do
        post :create, params: { member_id: member.id, workspace_id: workspace_with_multiple_members.id, member_role: WorkspaceMember.member_roles[:admin] }, as: :json
      end

      it "should return forbidden status" do
        expect(response.status).to eq(403)
      end
    end

    context "should not create duplicate workspace member in workspace" do
      before do
        member = workspace_with_multiple_members.members.take
        @workspace_members_count = workspace_with_multiple_members.workspace_members.count
        post :create, params: { member_id: member.id, workspace_id: workspace_with_multiple_members.id, member_role: WorkspaceMember.member_roles[:admin] }, as: :json
      end

      it "should return unprocessable entity status" do
        expect(response.status).to eq(422)
      end

      it "should check workspace members count same as before" do
        expect(workspace_with_multiple_members.workspace_members.count).to eq(@workspace_members_count)
      end
    end

    context "should not create workspace member for unauthenticated user" do
      let(:member) { create(:user, state: :active, current_stage: :registered, company: company) }

      it "should return unauthorized status" do
        allow(controller).to receive(:current_user).and_return(nil)
        post :create, params: { member_role: WorkspaceMember.member_roles[:user], member_id: member.id, workspace_id: workspace_with_multiple_members.id }, as: :json

        expect(response.status).to eq(401)
      end
    end
  end

  describe "GET #paginated" do
    context "should return paginated workspace members" do
      it "should return first page of workspace members per page 10" do
        params = {"draw"=>"1", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "4"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "5"=>{"data"=>"member.open_tasks_count", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"1", "dir"=>"asc"}}, "start"=>"0", "length"=>"10", "search"=>{"value"=>"", "regex"=>"false"},
          "workspace_id"=>"#{workspace_with_multiple_members.id}", "format"=>"json"
        }

        get :paginated, params: params

        data = JSON.parse(response.body)['data']
        expect(data.count).to eq(10)
      end

      it "should return second page of workspace members per page 10" do
        params = {"draw"=>"2", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "4"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "5"=>{"data"=>"member.open_tasks_count", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"1", "dir"=>"asc"}}, "start"=>"10", "length"=>"10", "search"=>{"value"=>"", "regex"=>"false"},
          "workspace_id"=>"#{workspace_with_multiple_members.id}", "format"=>"json"
        }

        get :paginated, params: params

        data = JSON.parse(response.body)['data']
        expect(data.count).to eq(10)
      end

      it "should return second page of workspace members per page 10" do
        params = {"draw"=>"3", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "4"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "5"=>{"data"=>"member.open_tasks_count", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"1", "dir"=>"asc"}}, "start"=>"20", "length"=>"10", "search"=>{"value"=>"", "regex"=>"false"},
          "workspace_id"=>"#{workspace_with_multiple_members.id}", "format"=>"json"
        }

        get :paginated, params: params

        data = JSON.parse(response.body)['data']
        expect(data.count).to eq(9)
      end

      it "should return paginated workspace members per page 25" do
        params = {"draw"=>"1", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "4"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "5"=>{"data"=>"member.open_tasks_count", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"1", "dir"=>"asc"}}, "start"=>"0", "length"=>"25", "search"=>{"value"=>"", "regex"=>"false"},
          "workspace_id"=>"#{workspace_with_multiple_members.id}", "format"=>"json"
        }

        get :paginated, params: params

        data = JSON.parse(response.body)['data']
        expect(data.count).to eq(25)
      end
    end

    context "should return paginated/filtered workspace members" do
      it "should return member preferred full name based filtered paginated workspace members in asc" do
        params = {"draw"=>"1", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"member.name", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "4"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "5"=>{"data"=>"member.open_tasks_count", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"1", "dir"=>"asc"}}, "start"=>"0", "length"=>"29", "search"=>{"value"=>"", "regex"=>"false"},
          "workspace_id"=>"#{workspace_with_multiple_members.id}", "format"=>"json"
        }

        get :paginated, params: params

        data = JSON.parse(response.body)['data']
        workspace_members = data.map {|data| data['member']}
        workspace_members_preferred_full_name = workspace_members.map { |member| member['preferred_full_name'] }

        expect(workspace_members_preferred_full_name).to eq(workspace_with_multiple_members.workspace_members.joins(:member).order('users.preferred_full_name asc').pluck(:preferred_full_name))
      end

      it "should return member preferred full name based filtered paginated workspace members in desc" do
        params = {"draw"=>"1", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"member.name", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "4"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "5"=>{"data"=>"member.open_tasks_count", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"1", "dir"=>"desc"}}, "start"=>"0", "length"=>"29", "search"=>{"value"=>"", "regex"=>"false"},
          "workspace_id"=>"#{workspace_with_multiple_members.id}", "format"=>"json"
        }

        get :paginated, params: params

        data = JSON.parse(response.body)['data']
        workspace_members = data.map {|data| data['member']}
        workspace_members_preferred_full_name = workspace_members.map { |member| member['preferred_full_name'] }

        expect(workspace_members_preferred_full_name).to eq(workspace_with_multiple_members.workspace_members.joins(:member).order('users.preferred_full_name desc').pluck(:preferred_full_name))
      end

      it "should return member title based filtered paginated workspace members in asc" do
        params = {"draw"=>"1", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"member.name", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"member.title", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "4"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "5"=>{"data"=>"member.open_tasks_count", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"2", "dir"=>"asc"}}, "start"=>"0", "length"=>"29", "search"=>{"value"=>"", "regex"=>"false"},
          "workspace_id"=>"#{workspace_with_multiple_members.id}", "format"=>"json"
        }

        get :paginated, params: params

        data = JSON.parse(response.body)['data']
        workspace_members = data.map {|data| data['member']}
        workspace_members_title = workspace_members.map { |member| member['title'] }

        expect(workspace_members_title).to eq(workspace_with_multiple_members.workspace_members.joins(:member).order('users.title asc').pluck(:title))
      end

      it "should return member title based filtered paginated workspace members in desc" do
        params = {"draw"=>"1", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"member.name", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"member.title", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "4"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "5"=>{"data"=>"member.open_tasks_count", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"2", "dir"=>"desc"}}, "start"=>"0", "length"=>"29", "search"=>{"value"=>"", "regex"=>"false"},
          "workspace_id"=>"#{workspace_with_multiple_members.id}", "format"=>"json"
        }

        get :paginated, params: params

        data = JSON.parse(response.body)['data']
        workspace_members = data.map {|data| data['member']}
        workspace_members_title = workspace_members.map { |member| member['title'] }

        expect(workspace_members_title).to eq(workspace_with_multiple_members.workspace_members.joins(:member).order('users.title desc').pluck(:title))
      end

      it "should return location based filtered paginated workspace members in asc" do
        params = {"draw"=>"1", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"member.name", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"member.title", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"member.location", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "4"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "5"=>{"data"=>"member.open_tasks_count", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"3", "dir"=>"asc"}}, "start"=>"0", "length"=>"29", "search"=>{"value"=>"", "regex"=>"false"},
          "workspace_id"=>"#{workspace_with_multiple_members.id}", "format"=>"json"
        }

        get :paginated, params: params

        data = JSON.parse(response.body)['data']
        workspace_members = data.map {|data| data['member']}
        workspace_members_location = workspace_members.map { |member| member['location'] }

        expect(workspace_members_location).to eq(workspace_with_multiple_members.workspace_members.joins("LEFT JOIN users ON users.id = workspace_members.member_id
          LEFT JOIN locations ON locations.id = users.location_id").order('locations.name asc').pluck(:name))
      end

      it "should return location based filtered paginated workspace members in desc" do
        params = {"draw"=>"1", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"member.name", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"member.title", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"member.location", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "4"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "5"=>{"data"=>"member.open_tasks_count", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"3", "dir"=>"desc"}}, "start"=>"0", "length"=>"29", "search"=>{"value"=>"", "regex"=>"false"},
          "workspace_id"=>"#{workspace_with_multiple_members.id}", "format"=>"json"
        }

        get :paginated, params: params

        data = JSON.parse(response.body)['data']
        workspace_members = data.map {|data| data['member']}
        workspace_members_location = workspace_members.map { |member| member['location'] }

        expect(workspace_members_location).to eq(workspace_with_multiple_members.workspace_members.joins("LEFT JOIN users ON users.id = workspace_members.member_id
          LEFT JOIN locations ON locations.id = users.location_id").order('locations.name desc').pluck(:name))
      end

      it "should return member role based filtered paginated workspace members in asc" do
        params = {"draw"=>"1", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"member.name", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"member.title", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"member.location", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "4"=>{"data"=>"member_role_name", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "5"=>{"data"=>"member.open_tasks_count", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"4", "dir"=>"asc"}}, "start"=>"0", "length"=>"29", "search"=>{"value"=>"", "regex"=>"false"},
          "workspace_id"=>"#{workspace_with_multiple_members.id}", "format"=>"json"
        }

        get :paginated, params: params
        data = JSON.parse(response.body)['data']
        workspace_member_roles = data.map {|data| data['member_role']}

        expect(workspace_member_roles).to eq(workspace_with_multiple_members.workspace_members.order('member_role asc').pluck(:member_role))
      end

      it "should return member role based filtered paginated workspace members in desc" do
        params = {"draw"=>"1", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"member.name", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"member.title", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"member.location", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "4"=>{"data"=>"member_role_name", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "5"=>{"data"=>"member.open_tasks_count", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"4", "dir"=>"desc"}}, "start"=>"0", "length"=>"29", "search"=>{"value"=>"", "regex"=>"false"},
          "workspace_id"=>"#{workspace_with_multiple_members.id}", "format"=>"json"
        }

        get :paginated, params: params

        data = JSON.parse(response.body)['data']
        workspace_member_roles = data.map {|data| data['member_role']}

        expect(workspace_member_roles).to eq(workspace_with_multiple_members.workspace_members.order('member_role desc').pluck(:member_role))
      end
    end

    context "should not return workspace members of other company" do
      let(:other_company) { create(:company, subdomain: 'boo') }
      let(:workspace_of_other_company) { create(:workspace_with_multiple_members, company: other_company, workspace_image: workspace_image) }

      before do
        params = {"draw"=>"1", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "4"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "5"=>{"data"=>"member.open_tasks_count", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"1", "dir"=>"asc"}}, "start"=>"0", "length"=>"10", "search"=>{"value"=>"", "regex"=>"false"},
          "workspace_id"=>"#{workspace_of_other_company.id}", "format"=>"json"
        }

        get :paginated, params: params
      end

      it "should return ok status" do
        expect(response.status).to eq(200)
      end

      it "should return blank as data" do
        data = JSON.parse(response.body)["data"]
        expect(data).to eq([])
      end
    end

    context "should not return workspace members for unauthenticated user" do
      it "should return unauthorized status" do
        allow(controller).to receive(:current_user).and_return(nil)
        params = {"draw"=>"1", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "4"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "5"=>{"data"=>"member.open_tasks_count", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"1", "dir"=>"asc"}}, "start"=>"0", "length"=>"10", "search"=>{"value"=>"", "regex"=>"false"},
          "workspace_id"=>"#{workspace_with_multiple_members.id}", "format"=>"json"
        }

        get :paginated, params: params
        expect(response.status).to eq(401)
      end
    end
  end
end
