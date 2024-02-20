require 'rails_helper'
require 'sidekiq/testing'
RSpec.describe Api::V1::Admin::UsersController, type: :controller do

  let(:company) { create(:gsuite_integration, is_using_custom_table: false , send_notification_before_start: true) }
  let(:other_company) { create(:company, subdomain: 'boo', is_using_custom_table: true) }
  let(:other_user) { create(:user, state: :active, current_stage: :registered, company: other_company) }
  let(:user1) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company, manager_id: user1.id) }
  let(:location) { create(:location, name: 'Test Location', company: company) }
  let(:team) { create(:team, name: 'Test Team', company: company) }
  let!(:employee) { create(:user, state: :active, current_stage: :registered, company: company, manager: user, location: location, team: team, role: User.roles[:employee]) }
  let(:tim) { create(:tim, company: company) }
  let(:nick) { create(:nick, :manager_with_role, company: company) }
  let(:admin) { create(:peter, company: company) }
  let(:super_admin) { create(:user, company: company) }
  let(:manager) { create(:user, company: company, role: User.roles[:employee]) }
  let(:admin_no_access) {create(:with_no_access_for_all, role_type: 2, company: company)}
  let(:task) { create(:task) }

  before do
    allow(controller).to receive(:current_user).and_return(super_admin)
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe '#basic' do
    context "should not return users" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        get :basic, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)

        get :basic, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is employee and sub_tab is present' do
        allow(controller).to receive(:current_user).and_return(employee)

        get :basic, params: { sub_tab: 'dashboard' }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is manager and sub_tab is present' do
        allow(controller).to receive(:current_user).and_return(nick.manager)

        get :basic, params: { sub_tab: 'dashboard' }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is admin and sub_tab is present but user has no access' do
        admin.update!(user_role: admin_no_access)
        allow(controller).to receive(:current_user).and_return(admin)

        get :basic, params: { sub_tab: 'dashboard' }, format: :json
        expect(response.status).to eq(204)
      end
    end

    context 'should return users' do
      it 'should return valid users with keys if current user is super admin and sub_tab is not present' do
        get :basic, format: :json
        result = JSON.parse(response.body)
        expect(result[0].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name",
                                      "preferred_full_name", "is_reset_password_token_set", "is_password_set",
                                      "about_you", "provider", "display_name_format", "title", "location_name",
                                      "seen_profile_setup", "seen_documents_v2", "ui_switcher",
                                      "email", "team_name", "picture", "personal_email", "display_first_name",
                                      "display_name"])
        expect(result[0].keys.count).to eq(22)
        expect(response.status).to eq(200)
      end


      it 'should return valid users with keys if current user is admin and sub_tab is not present' do
        allow(controller).to receive(:current_user).and_return(admin)

        get :basic, format: :json
        result = JSON.parse(response.body)
        expect(result[0].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name",
                                      "preferred_full_name", "is_reset_password_token_set", "is_password_set",
                                      "about_you", "provider", "display_name_format", "title", "location_name",
                                      "seen_profile_setup", "seen_documents_v2", "ui_switcher",
                                      "email", "team_name", "picture", "personal_email", "display_first_name",
                                      "display_name"])
        expect(result[0].keys.count).to eq(22)
        expect(response.status).to eq(200)
      end

      it 'should return valid users with keys if current user is employee and sub_tab is not present' do
        allow(controller).to receive(:current_user).and_return(employee)

        get :basic, format: :json
        result = JSON.parse(response.body)
        expect(result[0].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name",
                                      "preferred_full_name", "is_reset_password_token_set", "is_password_set",
                                      "about_you", "provider", "display_name_format", "title", "location_name",
                                      "seen_profile_setup", "seen_documents_v2", "ui_switcher",
                                      "email", "team_name", "picture", "personal_email", "display_first_name",
                                      "display_name"])
        expect(result[0].keys.count).to eq(22)
        expect(response.status).to eq(200)
      end

      it 'should return valid users with keys if current user is manager and sub_tab is not present' do
        allow(controller).to receive(:current_user).and_return(nick.manager)

        get :basic, format: :json
        result = JSON.parse(response.body)
        expect(result[0].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name",
                                      "preferred_full_name", "is_reset_password_token_set", "is_password_set",
                                      "about_you", "provider", "display_name_format", "title", "location_name",
                                      "seen_profile_setup", "seen_documents_v2", "ui_switcher",
                                      "email", "team_name", "picture", "personal_email", "display_first_name",
                                      "display_name"])
        expect(result[0].keys.count).to eq(22)
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#login_as_user' do
    context "should not return new_auth_token" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        post :login_as_user, params: { id: employee.id }, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)

        post :login_as_user, params: { id: employee.id }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return 204 status if current user is employee' do
        allow(controller).to receive(:current_user).and_return(tim)

        post :login_as_user, params: { id: employee.id }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return 204 status if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)

        post :login_as_user, params: { id: employee.id }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return 400 status and invalid message if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)

        post :login_as_user, params: { id: employee.id }, format: :json
        expect(JSON.parse(response.body)["message"]).to eq("Invalid user.")
        expect(response.status).to eq(400)
      end
    end

    context 'should return new_auth_token' do
      it 'should return new_auth_token if current user is super admin and other user is employee' do
        post :login_as_user, params: { id: employee.id }, format: :json

        result = JSON.parse(response.body)
        expect(result.keys).to eq(["access-token", "token-type", "client", "expiry", "uid"])
        expect(result.keys.count).to eq(5)
        expect(response.status).to eq(200)
      end

      it 'should return new_auth_token if current user is super admin and other user is own' do
        post :login_as_user, params: { id: super_admin.id }, format: :json

        result = JSON.parse(response.body)
        expect(result.keys).to eq(["access-token", "token-type", "client", "expiry", "uid"])
        expect(result.keys.count).to eq(5)
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#create_ghost_user' do
    context "should not return new_auth_token" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        post :create_ghost_user, params: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, expiration_date: 2.days.from_now, email: Faker::Internet.email }, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)

        post :create_ghost_user, params: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, expiration_date: 2.days.from_now, email: Faker::Internet.email }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return 204 status if current user is employee' do
        allow(controller).to receive(:current_user).and_return(tim)

        post :create_ghost_user, params: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, expiration_date: 2.days.from_now, email: Faker::Internet.email }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return 204 status if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)

        post :create_ghost_user, params: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, expiration_date: 2.days.from_now, email: Faker::Internet.email }, format: :json
        expect(response.status).to eq(204)
      end
    end

    context 'should return new_auth_token' do
      it 'should return 200 status and create ghost user if current user is super admin' do
        post :create_ghost_user, params: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, expiration_date: 2.days.from_now, email: Faker::Internet.email }, format: :json

        expect(company.users.where(user_role_id:  company.user_roles.find_by_name("Ghost Admin").id).count).to eq(1)
        expect(response.status).to eq(204)
      end


      it 'should return 200 status and create ghost user if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        post :create_ghost_user, params: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, expiration_date: 2.days.from_now, email: Faker::Internet.email }, format: :json

        expect(company.users.where(user_role_id:  company.user_roles.find_by_name("Ghost Admin").id).count).to eq(1)
        expect(response.status).to eq(204)
      end
    end
  end

  describe '#back_to_admin' do
    context "should not return new_auth_token" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        post :back_to_admin, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)

        post :back_to_admin, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return 200 status and empty body if current user is employee and session id is not present' do
        allow(controller).to receive(:current_user).and_return(tim)
        @request.session['super_admin_id'] = nil

        post :back_to_admin, format: :json
        expect(response.body).to eq("")
        expect(response.status).to eq(204)
      end

      it 'should return 200 status and empty body if current user is manager and session id is not present' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        @request.session['super_admin_id'] = nil

        post :back_to_admin, format: :json
        expect(response.body).to eq("")
        expect(response.status).to eq(204)
      end

      it 'should return 400 status and empty body if current user is admin and session id is not present' do
        allow(controller).to receive(:current_user).and_return(admin)
        @request.session['super_admin_id'] = nil

        post :back_to_admin, format: :json
        expect(response.body).to eq("")
        expect(response.status).to eq(204)
      end
    end

    context 'should return new_auth_token' do
      it 'should return new_auth_token if current user is super admin' do
        post :back_to_admin, params: { super_admin_id: super_admin.id }, format: :json

        result = JSON.parse(response.body)
        expect(result.keys).to eq(["access-token", "token-type", "client", "expiry", "uid"])
        expect(result.keys.count).to eq(5)
        expect(response.status).to eq(200)
      end

      it 'should return new_auth_token if current user is employee' do
        allow(controller).to receive(:current_user).and_return(tim)
        post :back_to_admin, params: { super_admin_id: tim.id }, format: :json

        result = JSON.parse(response.body)
        expect(result.keys).to eq(["access-token", "token-type", "client", "expiry", "uid"])
        expect(result.keys.count).to eq(5)
        expect(response.status).to eq(200)
      end

      it 'should return new_auth_token if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        post :back_to_admin, params: { super_admin_id: nick.manager.id }, format: :json

        result = JSON.parse(response.body)
        expect(result.keys).to eq(["access-token", "token-type", "client", "expiry", "uid"])
        expect(result.keys.count).to eq(5)
        expect(response.status).to eq(200)
      end

      it 'should return new_auth_token if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        post :back_to_admin, params: { super_admin_id: admin.id }, format: :json

        result = JSON.parse(response.body)
        expect(result.keys).to eq(["access-token", "token-type", "client", "expiry", "uid"])
        expect(result.keys.count).to eq(5)
        expect(response.status).to eq(200)
      end
    end
  end

  describe "GET #get_managed_users" do
    context "should not return managed_users" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        get :get_managed_users, params: { manager_id: nick.manager.id }, format: :json

        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        get :get_managed_users, params: { manager_id: nick.manager.id }, format: :json

        expect(response.status).to eq(204)
      end

      it 'should return 204 status if current user is employee' do
        allow(controller).to receive(:current_user).and_return(tim)
        get :get_managed_users, params: { manager_id: nick.manager.id }, format: :json

        expect(response.status).to eq(204)
      end

      it 'should return 204 status if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        get :get_managed_users, params: { manager_id: nick.manager.id }, format: :json

        expect(response.status).to eq(204)
      end
    end

    context "should return managed_users" do
      before do
        @userA = create(:user, company: company, manager_id: nick.manager.id)
        @userB = create(:user, company: company, manager_id: nick.manager.id)
        @userC = create(:user, company: company, manager_id: nick.manager.id)
      end

      it "should 200 status and valid keys and correctly return all managed users of a user if current_user is super admin" do
        allow(controller).to receive(:current_user).and_return(admin)
        response = get :get_managed_users, params: { manager_id: nick.manager.id }, format: :json

        expect(response.status).to eq(200)
        response = JSON.parse(response.body)
        expect(response.length).to eq(4)
        expect(response[0].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name", "preferred_full_name", "is_reset_password_token_set", "is_password_set", "about_you", "provider", "display_name_format", "title", "location_name", "seen_profile_setup", "seen_documents_v2", "ui_switcher", "picture", "profile_image", "manager"])
        ids_array = []
        ids_array.push(@userA.id)
        ids_array.push(@userB.id)
        ids_array.push(@userC.id)
        ids_array.push(nick.id)

        expect(ids_array).to include(response.first["id"])
        expect(ids_array).to include(response.second["id"])
        expect(ids_array).to include(response.third["id"])
        expect(ids_array).to include(response.fourth["id"])
      end

      it "should 200 status and valid keys and correctly return all managed users of a user if current_user is super admin" do
        response = get :get_managed_users, params: { manager_id: nick.manager.id }, format: :json

        expect(response.status).to eq(200)
        response = JSON.parse(response.body)
        expect(response.length).to eq(4)
        expect(response[0].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name", "preferred_full_name", "is_reset_password_token_set", "is_password_set", "about_you", "provider", "display_name_format", "title", "location_name", "seen_profile_setup", "seen_documents_v2", "ui_switcher", "picture", "profile_image", "manager"])
        ids_array = []
        ids_array.push(@userA.id)
        ids_array.push(@userB.id)
        ids_array.push(@userC.id)
        ids_array.push(nick.id)

        expect(ids_array).to include(response.first["id"])
        expect(ids_array).to include(response.second["id"])
        expect(ids_array).to include(response.third["id"])
        expect(ids_array).to include(response.fourth["id"])
      end
    end
  end

  describe '#group_basic' do
    context "should not return users" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        get :group_basic, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)

        get :group_basic, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)

        get :group_basic, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)

        get :group_basic, format: :json
        expect(response.status).to eq(204)
      end
    end

    context 'should return users' do
      it 'should return 200 status if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)

        get :group_basic, format: :json

        result = JSON.parse(response.body)
        expect(result[0].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name",
                                      "preferred_full_name", "is_reset_password_token_set", "is_password_set",
                                      "about_you", "provider", "display_name_format", "title", "location_name",
                                      "seen_profile_setup", "seen_documents_v2", "ui_switcher",
                                      "email", "team_name", "picture", "personal_email", "display_first_name",
                                      "display_name", "profile_image"])
        expect(result[0].keys.count).to eq(23)
        expect(response.status).to eq(200)
      end
      it 'should return valid users with keys if current user is super admin' do
        get :group_basic, format: :json

        result = JSON.parse(response.body)
        expect(result[0].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name",
                                      "preferred_full_name", "is_reset_password_token_set", "is_password_set",
                                      "about_you", "provider", "display_name_format", "title", "location_name",
                                      "seen_profile_setup", "seen_documents_v2", "ui_switcher",
                                      "email", "team_name", "picture", "personal_email", "display_first_name",
                                      "display_name", "profile_image"])
        expect(result[0].keys.count).to eq(23)
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#offboarding_basic' do
    context "should not return users" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        get :offboarding_basic, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)

        get :offboarding_basic, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)

        get :offboarding_basic, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)

        get :offboarding_basic, format: :json
        expect(response.status).to eq(204)
      end
    end

    context 'should return users' do
      it 'should return 200 status if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)

        get :offboarding_basic, format: :json

        result = JSON.parse(response.body)
        expect(result[0].keys).to eq(["id", "email", "personal_email", "title", "first_name", "last_name", "preferred_full_name", "location_name", "start_date", "last_day_worked", "date_of_birth", "termination_date", "preferred_name", "team", "location", "employee_type", "manager", "buddy"])
        expect(result[0].keys.count).to eq(18)
        expect(response.status).to eq(200)
      end
      it 'should return valid users with keys if current user is super admin' do
        get :offboarding_basic, format: :json

        result = JSON.parse(response.body)
        expect(result[0].keys).to eq(["id", "email", "personal_email", "title", "first_name", "last_name", "preferred_full_name", "location_name", "start_date", "last_day_worked", "date_of_birth", "termination_date", "preferred_name", "team", "location", "employee_type", "manager", "buddy"])
        expect(result[0].keys.count).to eq(18)
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#index' do
    context "should not return users" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        get :index, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)

        get :index, format: :json
        expect(response.status).to eq(204)
      end
    end

    context 'should return users' do
      it 'should return ok status if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)

        get :index, format: :json
        expect(response.status).to eq(200)
      end

      it 'should return ok status if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)

        get :index, format: :json
        expect(response.status).to eq(200)
      end

      it 'should return 200 status if current user is admin and multi_select_options is present' do
        allow(controller).to receive(:current_user).and_return(admin)
        get :index, format: { multi_select_options: true }, format: :json

        result = JSON.parse(response.body)
        expect(result[0].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name", "picture", "preferred_full_name", "title", "location_name"])
        expect(result[0].keys.count).to eq(9)
        expect(response.status).to eq(200)
      end

      it 'should return 200 status if current user is admin and multi_select_options is not present' do
        allow(controller).to receive(:current_user).and_return(admin)
        get :index, format: :json

        result = JSON.parse(response.body)
        expect(result[0].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name", "picture", "preferred_full_name", "title", "location_name"])
        expect(result[0].keys.count).to eq(9)
        expect(response.status).to eq(200)
      end

      it 'should return valid users with keys if current user is super admin and multi_select_options is not present' do
        get :index, format: :json

        result = JSON.parse(response.body)
        expect(result[0].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name", "picture", "preferred_full_name", "title", "location_name"])
        expect(result[0].keys.count).to eq(9)
        expect(response.status).to eq(200)
      end

      it 'should return valid users with keys if current user is super admin and multi_select_options is present' do
        get :index, params: { multi_select_options: true }, format: :json

        result = JSON.parse(response.body)
        expect(result[0].keys).to eq(["id", "name"])
        expect(result[0].keys.count).to eq(2)
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#create' do
    context "should not create user" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        post :create, params: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, start_date: 2.days.ago, email: 'test@gmail.com', title: Faker::Name.title }, format: :json

        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        post :create, params: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, start_date: 2.days.ago, email: 'test@gmail.com', title: Faker::Name.title }, format: :json

        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        post :create, params: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, start_date: 2.days.ago, email: 'test@gmail.com', title: Faker::Name.title }, format: :json

        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        post :create, params: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, start_date: 2.days.ago, email: 'test@gmail.com', title: Faker::Name.title }, format: :json

        expect(response.status).to eq(204)
      end
    end

    context 'should create user' do
      it 'should return 201 status if current user is admin and create history and perform slack and push event jobs' do
        allow(controller).to receive(:current_user).and_return(admin)
        push_event_job_size = Sidekiq::Queues["default"].size
        slack_notification_job_size = Sidekiq::Queues["slack_notification"].size

        post :create, params: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, start_date: 2.days.ago, email: 'test@gmail.com', title: Faker::Name.title }, format: :json

        result = JSON.parse(response.body)
        expect(result['email']).to eq('test@gmail.com')
        expect(result.keys.count).to eq(95)
        expect(response.status).to eq(201)

        expect(company.histories.count).to eq(2)
        expect(Sidekiq::Queues["slack_notification"].size).to eq(slack_notification_job_size + 1)
        expect(Sidekiq::Queues["default"].size).to eq( push_event_job_size + 1)
      end

      it 'should return 201 status if current user is super admin and create history and perform slack and push event jobs' do
        push_event_job_size = Sidekiq::Queues["default"].size
        slack_notification_job_size = Sidekiq::Queues["slack_notification"].size

        post :create, params: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, start_date: 2.days.ago, email: 'test@gmail.com', title: Faker::Name.title }, format: :json

        result = JSON.parse(response.body)
        expect(result['email']).to eq('test@gmail.com')
        expect(result.keys.count).to eq(95)
        expect(response.status).to eq(201)

        expect(company.histories.count).to eq(2)
        expect(Sidekiq::Queues["slack_notification"].size).to eq(slack_notification_job_size + 1)
        expect(Sidekiq::Queues["default"].size).to eq( push_event_job_size + 1)
      end
    end
  end

  describe '#show' do
    context "should not return user" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        get :show, params: { id: employee.id }, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)

        get :show, params: { id: employee.id }, format: :json
        expect(response.status).to eq(204)
      end
    end

    context 'should return user' do
      it 'should return no content status if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        get :show, params: { id: employee.id }, format: :json

        expect(JSON.parse(response.body).keys.count).to eq(95)
        expect(response.status).to eq(200)
      end
        it 'should return ok status if current user is employee and get own data' do
        allow(controller).to receive(:current_user).and_return(employee)
        get :show, params: { id: employee.id }, format: :json

        expect(JSON.parse(response.body).keys.count).to eq(95)
        expect(response.status).to eq(200)
      end

      it 'should return 200 status if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        get :show, params: { id: employee.id }, format: :json

        expect(JSON.parse(response.body).keys.count).to eq(95)
        expect(response.status).to eq(200)
      end

      it 'should return valid users with keys if current user is super admin' do
        get :show, params: { id: employee.id }, format: :json

        expect(JSON.parse(response.body).keys.count).to eq(95)
        expect(response.status).to eq(200)
      end
    end
  end

  describe "PUT #update" do
    context "should not update user" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        put :update, params: { id: employee.id, manager_id: nil }, format: :json

        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        put :update, params: { id: employee.id, manager_id: nil }, format: :json

        expect(response.status).to eq(204)
      end
    end

    context 'should update user' do
      it 'should return 200 status and update user if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        put :update, params: { id: employee.id, team_id: nil }, format: :json

        expect(response.status).to eq(200)
        expect(employee.reload.team_id).to eq(nil)
      end

      it 'should return 200 status and update user if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        put :update, params: { id: employee.id, title: 'abc' }, format: :json

        expect(response.status).to eq(200)
        expect(employee.reload.title).to eq('abc')
      end
      it 'should return 200 status if current user is admin and update user' do
        allow(controller).to receive(:current_user).and_return(admin)
        put :update, params: { id: employee.id, manager_id: nil }, format: :json

        expect(response.status).to eq(200)
        expect(employee.reload.manager_id).to eq(nil)
      end

      it "should return 200 status if current user is super admin and update user and enqueue jobs" do
        bamboo_integration = create(:bamboohr_integration, company: company)
        tim.update_column(:bamboo_id, '123')
        put :update, params: { id: tim.id, location_id: nil, state: 'active' }, format: :json

        expect(response).to have_http_status(200)
        expect(Sidekiq::Queues["slack_notification"].size).not_to eq(0)
        expect(Sidekiq::Queues["default"].size).not_to eq(0)
        expect(Sidekiq::Queues["update_employee_to_hr"].size).not_to eq(0)
        expect(tim.reload.location_id).to eq(nil)
      end
    end
  end

  describe '#paginated' do
    context "should not return users" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        get :paginated, params: { basic: true, per_page: 2 }, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)

        get :paginated, params: { basic: true, per_page: 2 }, format: :json
        expect(response.status).to eq(204)
      end
    end

    context 'should return users' do
      it 'should return ok status if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)

        get :paginated, params: { basic: true, per_page: 2 }, format: :json
        expect(response.status).to eq(200)
      end

      it 'should return ok status if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)

        get :paginated, params: { basic: true, per_page: 2 }, format: :json
        expect(response.status).to eq(200)
      end

      it 'should return 200 status if current user is admin and basic is present' do
        allow(controller).to receive(:current_user).and_return(admin)
        get :paginated, params: { basic: true, per_page: 2 }, format: :json

        result = JSON.parse(response.body)
        expect(result["users"][0].keys.count).to eq(35)
        expect(result["users"][0].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name",
                                                "preferred_full_name", "is_reset_password_token_set", "is_password_set",
                                                "about_you", "provider", "display_name_format", "title", "location_name",
                                                "seen_profile_setup", "seen_documents_v2", "ui_switcher",
                                                "email", "team_name", "picture", "personal_email", "display_first_name",
                                                "display_name", "state", "manager_name", "medium_picture", "location_id",
                                                "team_id", "current_stage", "employee_type", "start_date", "last_day_worked", "user_role",
                                                "managed_users_ids", "indirect_reports_ids", "manager"])

        expect(result.keys.count).to eq(2)
        expect(result.keys).to eq(["users", "meta"])
        expect(response.status).to eq(200)
      end

      it 'should return valid users with keys if current user is super admin and multi_select_options is not present' do
        get :paginated, params: { permissions: true, per_page: 2 }, format: :json

        result = JSON.parse(response.body)
        expect(result["users"][0].keys.count).to eq(25)
        expect(result["users"][0].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name",
                                              "preferred_full_name", "is_reset_password_token_set", "is_password_set",
                                              "about_you", "provider", "display_name_format", "title", "location_name",
                                              "seen_profile_setup", "seen_documents_v2", "ui_switcher", 
                                              "email", "team_name", "picture", "personal_email", "display_first_name",
                                              "display_name", "employee_type", "role", "last_activity_at"])
        expect(result.keys.count).to eq(2)
        expect(result.keys).to eq(["users", "meta"])
        expect(response.status).to eq(200)
      end

      it 'should return valid users with keys if current user is super admin no option is present' do
        get :paginated, params: { per_page: 2 }, format: :json

        result = JSON.parse(response.body)
        expect(result["users"][0].keys.count).to eq(45)
        expect(result.keys.count).to eq(2)
        expect(result.keys).to eq(["users", "meta"])
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#datatable_paginated' do
    before do
      @params = {"draw"=>"1", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"1", "dir"=>"asc"}}, "start"=>"0", "length"=>"1", "search"=>{"value"=>"", "regex"=>"false"}, "format"=>"json"}
    end

    context "should not return users" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        get :datatable_paginated, params: @params
        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)

        get :datatable_paginated, params: @params
        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is employee and sub_tab is present' do
        allow(controller).to receive(:current_user).and_return(employee)

        get :datatable_paginated, params: @params.merge!('sub_tab' => 'dashboard')
        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is manager and sub_tab is present' do
        allow(controller).to receive(:current_user).and_return(nick.manager)

        get :datatable_paginated, params: @params.merge!('sub_tab' => 'dashboard')
        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is admin and sub_tab is present but user has no access' do
        admin.update!(user_role: admin_no_access)
        allow(controller).to receive(:current_user).and_return(admin)

        get :datatable_paginated, params: @params.merge!('sub_tab' => 'dashboard')
        expect(response.status).to eq(204)
      end
    end

    context 'should return users' do
      it 'should return valid users with keys if current user is super admin and sub_tab is not present' do
        admin.save
        get :datatable_paginated, params: @params

        result = JSON.parse(response.body)
        expect(result.keys).to eq(["draw", "recordsTotal", "recordsFiltered", "data"])
        expect(result.keys.count).to eq(4)
        expect(result["data"].count).to eq(1)
        expect(response.status).to eq(200)
      end


      it 'should return valid users with keys if current user is admin and sub_tab is not present' do
        allow(controller).to receive(:current_user).and_return(admin)

        get :datatable_paginated, params: @params

        result = JSON.parse(response.body)
        expect(result.keys).to eq(["draw", "recordsTotal", "recordsFiltered", "data"])
        expect(result.keys.count).to eq(4)
        expect(result["data"].count).to eq(1)
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#bulk_assign_onboarding_template' do
    let(:profile_template) {create(:profile_template, company: company, process_type: company.process_types.where(name: 'Onboarding').first, name: 'US Profile Templates')}

    it "should return unauthorised status for unauthenticated user" do
      allow(controller).to receive(:current_user).and_return(nil)

      get :bulk_assign_onboarding_template, params: {}
      expect(response.status).to eq(401)
    end

    it 'should return no content status for other company' do
      allow(controller).to receive(:current_company).and_return(other_company)

      get :bulk_assign_onboarding_template, params: {}
      expect(response.status).to eq(204)
    end

    it 'should return success ' do
      Sidekiq::Testing.inline! do
        get :bulk_assign_onboarding_template, params: {users: [user.id], template_id: profile_template.id, remove_existing_values: true}
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['template_assigned']).to eq('true')
        expect(user.reload.onboarding_profile_template_id).to eq(profile_template.id)
      end
    end

    it 'should return error if template id not present' do
      Sidekiq::Testing.inline! do
        get :bulk_assign_onboarding_template, params: {users: [user.id], remove_existing_values: true}
        expect(response.status).to eq(400)
        expect(user.reload.onboarding_profile_template_id).to_not eq(profile_template.id)
      end
    end

    it 'should not assign if user id not present' do
      Sidekiq::Testing.inline! do
        get :bulk_assign_onboarding_template, params: {users: [], template_id: profile_template.id, remove_existing_values: true}
        expect(response.status).to eq(200)
        expect(user.reload.onboarding_profile_template_id).to_not eq(profile_template.id)
      end
    end
  end
end
