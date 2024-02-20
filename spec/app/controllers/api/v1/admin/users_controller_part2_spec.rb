require 'rails_helper'
require 'sidekiq/testing'
RSpec.describe :UsersControllerPart2, type: :controller do
  def self.described_class
    Api::V1::Admin::UsersController
  end

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
  let!(:webhook) {create(:webhook, event: 'offboarding', configurable: { stages: ['all'] }, company: company)}

  before do
    allow(controller).to receive(:current_user).and_return(super_admin)
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe '#home_group_paginated' do
    context "should not return users" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        get :home_group_paginated, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)

        get :home_group_paginated, format: :json
        expect(response.status).to eq(204)
      end

    end

    context 'should return users' do
      it 'should return no content status if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        get :home_group_paginated, format: :json

        result = JSON.parse(response.body)
        expect(result.keys).to eq(["users", "meta"])
        expect(response.status).to eq(200)
      end

      it 'should return no content status if current user is manager ' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        get :home_group_paginated, format: :json

        result = JSON.parse(response.body)
        expect(result.keys).to eq(["users", "meta"])
        expect(response.status).to eq(200)
      end

      it 'should return valid users with keys if current user is super admin' do
        admin.save
        get :home_group_paginated, format: :json

        result = JSON.parse(response.body)
        expect(result.keys).to eq(["users", "meta"])
        expect(response.status).to eq(200)
      end


      it 'should return valid users with keys if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        get :home_group_paginated, format: :json

        result = JSON.parse(response.body)
        expect(result.keys).to eq(["users", "meta"])
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#all_open_activities' do
    context "should not return all_open_activities" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        get :all_open_activities, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)

        get :all_open_activities, format: :json
        expect(response.status).to eq(204)
      end
      it 'should return no content status if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        get :all_open_activities, format: :json

        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is manager ' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        get :all_open_activities, format: :json

        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is admin and has no access' do
        admin.update!(user_role: admin_no_access)
        allow(controller).to receive(:current_user).and_return(admin)
        get :all_open_activities, format: :json

        result = JSON.parse(response.body)
        expect(result.keys).to eq(["open_activities_count", "overdue_activities_count"])
        expect(result.keys.count).to eq(2)
        expect(response.status).to eq(200)
      end

    end

    context 'should return all_open_activities' do
      it 'should return valid users with keys if current user is super admin' do
        get :all_open_activities, format: :json

        result = JSON.parse(response.body)
        expect(result.keys).to eq(["open_activities_count", "overdue_activities_count"])
        expect(result.keys.count).to eq(2)
        expect(response.status).to eq(200)
      end


      it 'should return valid users with keys if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        get :all_open_activities, format: :json

        result = JSON.parse(response.body)
        expect(result.keys).to eq(["open_activities_count", "overdue_activities_count"])
        expect(result.keys.count).to eq(2)
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#get_role_users' do
    context "should not return get_role_users" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        get :get_role_users, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)

        get :get_role_users, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)

        get :get_role_users, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)

        get :get_role_users, format: :json
        expect(response.status).to eq(204)
      end
    end

    context 'should return get_role_users' do
      it 'should return 200 status if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        get :get_role_users, format: :json
        result = JSON.parse(response.body)

        expect(result.keys).to eq(["users", "meta"])
        expect(result.keys.count).to eq(2)
        expect(response.status).to eq(200)
      end

      it 'should return valid users with keys if current user is super admin' do
        get :get_role_users, format: :json
        result = JSON.parse(response.body)

        expect(result.keys).to eq(["users", "meta"])
        expect(result.keys.count).to eq(2)
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#all_open_tasks' do
    context "should not return all_open_tasks" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        get :all_open_tasks, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)

        get :all_open_tasks, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)

        get :all_open_tasks, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)

        get :all_open_tasks, format: :json
        expect(response.status).to eq(204)
      end
    end

    context 'should return all_open_tasks' do
      it 'should return 200 status if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        get :all_open_tasks, format: :json
        result = JSON.parse(response.body)

        expect(result.keys).to eq(["open_activities_count", "overdue_activities_count"])
        expect(result.keys.count).to eq(2)
        expect(response.status).to eq(200)
      end

      it 'should return valid users with keys if current user is super admin' do
        get :all_open_tasks, format: :json
        result = JSON.parse(response.body)

        expect(result.keys).to eq(["open_activities_count", "overdue_activities_count"])
        expect(result.keys.count).to eq(2)
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#complete_user_activities' do
    before do
      task_user_connection = create(:task_user_connection, user: employee, task: task, state: 'in_progress')
    end

    context "should not return complete_user_activities" do
      it "should return unauthorised status and doesnot complete activity for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        get :complete_user_activities, params: { id: employee.id }, format: :json
        expect(employee.task_user_connections.take.state).to eq('in_progress')
        expect(response.status).to eq(401)
      end

      it 'should return no content status and doesnot complete activity for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        post :complete_user_activities, params: { id: employee.id }, format: :json

        expect(employee.task_user_connections.take.state).to eq('in_progress')
        expect(response.status).to eq(204)
      end

      it 'should return no content status  and doesnot complete activity if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        post :complete_user_activities, params: { id: employee.id }, format: :json

        expect(employee.task_user_connections.take.state).to eq('in_progress')
        expect(response.status).to eq(204)
      end
    end

    context 'should return complete_user_activities' do
      it 'should return no content status and complete own activity if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        post :complete_user_activities, params: { id: employee.id }, format: :json

        expect(employee.task_user_connections.take.state).to eq('completed')
        expect(response.status).to eq(204)
      end

      it 'should return 200 status and complete activity if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        post :complete_user_activities, params: { id: employee.id }, format: :json

        expect(employee.task_user_connections.take.state).to eq('completed')
        expect(response.status).to eq(204)
      end

      it 'should return 204 status and complete activity if current user is super admin' do
        post :complete_user_activities, params: { id: employee.id }, format: :json

        expect(employee.task_user_connections.take.state).to eq('completed')
        expect(response.status).to eq(204)
      end
    end
  end

  describe '#get_users_for_permissions' do
    context "should not return get_users_for_permissions" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        get :get_users_for_permissions, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)

        get :get_users_for_permissions, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)

        get :get_users_for_permissions, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return no content status if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)

        get :get_users_for_permissions, format: :json
        expect(response.status).to eq(204)
      end
    end

    context 'should return get_users_for_permissions' do
      it 'should return 200 status if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        get :get_users_for_permissions, format: :json
        result = JSON.parse(response.body)

        expect(result.keys).to eq(["users", "meta"])
        expect(result.keys.count).to eq(2)
        expect(response.status).to eq(200)
      end

      it 'should return valid users with keys if current user is super admin' do
        get :get_users_for_permissions, format: :json
        result = JSON.parse(response.body)

        expect(result.keys).to eq(["users", "meta"])
        expect(result.keys.count).to eq(2)
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#bulk_delete' do
    before do
      @user_a = FactoryGirl.create(:user, company: company, email: "userA@test.com")
      @user_b = FactoryGirl.create(:user, company: company, email: "userB@test.com")

      @user_ids = []
      @user_ids.push(@user_a.id)
      @user_ids.push(@user_b.id)
    end

    context "should not bulk_delete" do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        response = post :bulk_delete, params: { user_ids: @user_ids }, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return no content status for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)

        response = post :bulk_delete, params: { user_ids: @user_ids }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return no content status and doesnot delete users if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)

        response = post :bulk_delete, params: { user_ids: @user_ids }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return no content status and doesnot delete users if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)

        response = post :bulk_delete, params: { user_ids: @user_ids }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return 200 status and doesnot delete users if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        response = post :bulk_delete, params: { user_ids: @user_ids }, format: :json

        expect(response.status).to eq(200)
        expect(@user_a.deleted_at).to eq(nil)
        expect(@user_b.deleted_at).to eq(nil)
      end
    end

    context 'should bulk_delete' do
      it 'should return 200 status and delete users if current user is super admin' do
        histories = company.histories.count
        Sidekiq::Queues["default"].clear
        Sidekiq::Queues["slack_notification"].clear

        expect(@user_a.deleted_at).to eq(nil)
        expect(@user_b.deleted_at).to eq(nil)

        response = post :bulk_delete, params: { user_ids: @user_ids }, format: :json
        expect(response.status).to eq(200)

        expect(Sidekiq::Queues["default"].size).not_to eq(0)
        expect(Sidekiq::Queues["slack_notification"].size).not_to eq(0)
        expect(company.histories.count).to eq(histories + 2)

        expect(@user_a.reload.deleted_at).not_to eq(nil)
        expect(@user_b.reload.deleted_at).not_to eq(nil)
      end
    end
  end

  describe '#destroy' do
    context "should not destroy user" do
      it "should return unauthorised status and doesnot destroy user for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)

        delete :destroy, params: { id: employee.id }, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return no content status and doesnot destroy user for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        delete :destroy, params: { id: employee.id }, format: :json

        expect(response.status).to eq(204)
      end

      it 'should return no content status and doesnot destroy user if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        delete :destroy, params: { id: employee.id }, format: :json

        expect(employee.deleted_at).to eq(nil)
        expect(response.status).to eq(204)
      end
    end

    context 'should destroy user' do
      it 'should return no content status and own destroy user if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        expect(employee.deleted_at).to eq(nil)
        previous_delete_user_job_count = Sidekiq::Queues["delete_user"].size
        expect(employee.reload.visibility).to eq(true)

        delete :destroy, params: { id: employee.id }, format: :json

        expect(employee.reload.visibility).to eq(false)
        expect(Sidekiq::Queues["delete_user"].size).to eq(previous_delete_user_job_count + 1)
        expect(response.status).to eq(204)
      end

      it 'should return 200 status and complete activity if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        expect(employee.deleted_at).to eq(nil)
        previous_delete_user_job_count = Sidekiq::Queues["delete_user"].size
        expect(employee.reload.visibility).to eq(true)

        delete :destroy, params: { id: employee.id }, format: :json

        expect(employee.reload.visibility).to eq(false)
        expect(Sidekiq::Queues["delete_user"].size).to eq(previous_delete_user_job_count + 1)
        expect(response.status).to eq(204)
      end

      it 'should return 204 status and complete activity if current user is super admin' do
        expect(employee.deleted_at).to eq(nil)
        previous_delete_user_job_count = Sidekiq::Queues["delete_user"].size
        expect(employee.reload.visibility).to eq(true)

        delete :destroy, params: { id: employee.id }, format: :json

        expect(employee.reload.visibility).to eq(false)
        expect(Sidekiq::Queues["delete_user"].size).to eq(previous_delete_user_job_count + 1)
        expect(response.status).to eq(204)
      end
    end
  end

  describe '#send_tasks_email' do
    subject(:request) { post :send_tasks_email, params: { id: @user_b.id, 'task_ids': @task_ids_array }, format: :json }

    before do
      user_a = FactoryGirl.create(:user, company: company, state: 'active', current_stage: 'registered', email: "userA@test.com")
      @user_b = FactoryGirl.create(:user, company: company, state: 'active', current_stage: 'registered', email: "userB@test.com")

      workstream = create(:workstream, company: company)
      task_a = create(:task, workstream: workstream)
      task_b = create(:task, workstream: workstream)

      tuc_a = create(:task_user_connection, owner: user_a, task: task_a, user: @user_b)
      tuc_b = create(:task_user_connection, owner: user_a, task: task_b, user: @user_b)

      @task_ids_array = []
      @task_ids_array.push(task_a.id)
      @task_ids_array.push(task_b.id)
    end

    context "should not send_tasks_email" do
      it "should return unauthorised status and doesnot send_tasks_email for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        expect(request).to have_http_status(401)
      end

      it 'should return no content status and doesnot send_tasks_email for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot send_tasks_email if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        expect(request).to have_http_status(204)
      end
      it 'should return no content status and doesnot send_tasks_email if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        expect(request).to have_http_status(204)
      end
    end

    context "should send_tasks_email" do
      it 'should send tasks emails to users if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)

        Sidekiq::Testing.inline! do
          response = post :send_tasks_email, params: { id: @user_b.id, 'task_ids': @task_ids_array }, format: :json
          expect(response.status).to eq(201)
          response = JSON.parse(response.body)
          expect(response["sent_email_count"]).to eq(1)
        end
      end

      it 'should send tasks emails to users if current user is super admin' do
        Sidekiq::Testing.inline! do
          response = post :send_tasks_email, params: { id: @user_b.id, 'task_ids': @task_ids_array }, format: :json
          expect(response.status).to eq(201)
          response = JSON.parse(response.body)
          expect(response["sent_email_count"]).to eq(1)
        end
      end
    end
  end

  describe '#test_digest_email' do
    subject(:request) { post :test_digest_email, params: { id: nick.manager.id }, as: :json }

    before do
      date = Date.today
      unless date.monday?
        nick.update!(start_date: (date + 1.week).beginning_of_week(:monday) - 1.years)
      else
        nick.update!(start_date: date - 1.years)
      end
    end

    context "should not test_digest_email" do
      it "should return unauthorised status and doesnot test_digest_email for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        expect(request).to have_http_status(401)
      end

      it 'should return no content status and doesnot test_digest_email for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot test_digest_email if current_user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        expect(request).to have_http_status(204)
      end
    end

    context "should test_digest_email" do
      it 'should return send test_digest_email own if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        expect{ request }.to change { company.company_emails.count }.by(1)
      end

      it 'should send test_digest_email to users if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        expect{ request }.to change { company.company_emails.count }.by(1)
      end

      it 'should send test_digest_email to users if current user is super admin' do
        expect{ request }.to change { company.company_emails.count }.by(1)
      end
    end
  end

  describe '#resend_invitation' do
    subject(:request) { post :resend_invitation, params: { id: employee.id }, format: :json }

    context "should not resend_invitation" do
      it "should return unauthorised status and doesnot resend_invitation for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        expect(request).to have_http_status(401)
      end

      it 'should return no content status and doesnot resend_invitation for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot resend_invitation if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        expect(request).to have_http_status(204)
      end
    end

    context "should resend_invitation" do
      it 'should send resend_invitation to users if current user is own and employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        expect{ request }.to change { company.company_emails.count }.by(1)
      end

      it 'should send resend_invitation to users if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        expect{ request }.to change { company.company_emails.count }.by(1)
      end

      it 'should send resend_invitation to users if current user is super admin' do
        expect{ request }.to change { company.company_emails.count }.by(1)
      end
    end
  end

  describe '#get_job_titles' do
    subject(:request) { get :get_job_titles, format: :json }

    context "should not send_documents_email" do
      it "should return unauthorised status and doesnot send_documents_email for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        expect(request).to have_http_status(401)
      end

      it 'should return no content status and doesnot send_documents_email for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot send_documents_email if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot send_documents_email if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        expect(request).to have_http_status(204)
      end
    end

    context "should send_documents_email" do
      it 'should send send_documents_email to users if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        get :get_job_titles, format: :json

        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body).keys.count).to eq(1)
        expect(JSON.parse(response.body).keys).to eq(["data"])
      end

      it 'should send send_documents_email to users if current user is super admin' do
        get :get_job_titles, format: :json

        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body).keys.count).to eq(1)
        expect(JSON.parse(response.body).keys).to eq(["data"])
      end
    end
  end

  describe '#invite_user' do
    subject(:request) { post :invite_user, params: { id: employee.id, invited_employee: true }, format: :json }

    context "should not invite_user" do
      it "should return unauthorised status and doesnot invite_user for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        expect(request).to have_http_status(401)
      end

      it 'should return no content status and doesnot invite_user for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot invite_user if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        expect(request).to have_http_status(204)
      end
    end

    context "should invite_user" do
      it 'should return invite_user if current user is own and employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        expect{ request }.to change { company.company_emails.count }.by(1)
      end

      it 'should send invite_user users if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        expect{ request }.to change { company.company_emails.count }.by(1)
      end

      it 'should send invite_user users if current user is super admin' do
        expect{ request }.to change { company.company_emails.count }.by(1)
      end
    end
  end

  describe '#invite_users' do
    subject(:request) { post :invite_users, params: { user_ids: [employee.id] }, format: :json }

    context "should not invite_user" do
      it "should return unauthorised status and doesnot invite_user for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        expect(request).to have_http_status(401)
      end

      it 'should return no content status and doesnot invite_user for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot invite_user if current user is employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot invite_user if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        expect(request).to have_http_status(204)
      end

      it 'should not send invite_user users if current user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        Sidekiq::Queues['default'].clear
        size = Sidekiq::Queues['default'].size
        post :invite_users, params: { user_ids: [admin.id] }, format: :json
        expect(Sidekiq::Queues['default'].size).to eq(size+1)
      end
    end

    context "should invite_user" do
      it 'should send invite_user users if current user is super admin' do
        Sidekiq::Queues['default'].clear
        size = Sidekiq::Queues['default'].size
        post :invite_users, params: { user_ids: [super_admin.id] }, format: :json

        expect(Sidekiq::Queues['default'].size).to eq(size + 1)
      end
    end
  end

  describe '#offboard_user' do
    subject(:request) { post :offboard_user, params: { id: employee.id }, format: :json }

    context "should not offboard_user" do
      it "should return unauthorised status and doesnot offboard_user for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        expect(request).to have_http_status(401)
      end

      it 'should return no content status and doesnot offboard_user for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot offboard_user if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        expect(request).to have_http_status(204)
      end
    end

    context "should offboard_user" do
      before do
        employee.update!(namely_id: '123')
        employee.update!(bamboo_id: '123')
      end
      it 'should return  offboard_user if current user is own and employee' do
        allow(controller).to receive(:current_user).and_return(employee)
        expect(request).to have_http_status(201)
      end

      # it 'should offboard_user users if current user is admin' do
      #   allow(controller).to receive(:current_user).and_return(admin)
      #   histories = company.histories.count

      #   post :offboard_user, params: { id: employee.id, last_day_worked: 2.days.ago, termination_date: 2.days.ago }, format: :json

      #   expect(company.histories.count).to eq(histories + 1)
      #   expect(Sidekiq::Queues['receive_employee_from_hr'].size).not_to eq(0)
      #   expect(Sidekiq::Queues['slack_notification'].size).not_to eq(0)
      #   expect(Sidekiq::Queues['manage_custom_alert'].size).not_to eq(0)
      #   expect(employee.reload.last_day_worked).to eq(2.days.ago.to_date)
      #   expect(employee.reload.termination_date).to eq(2.days.ago.to_date)

      # end
      # it 'should send offboard_user users if current user is super admin' do
      #   histories = company.histories.count

      #   post :offboard_user, params: { id: employee.id, last_day_worked: 2.days.ago, termination_date: 2.days.ago }, format: :json

      #   expect(company.histories.count).to eq(histories + 1)
      #   expect(Sidekiq::Queues['receive_employee_from_hr'].size).not_to eq(0)
      #   expect(Sidekiq::Queues['slack_notification'].size).not_to eq(0)
      #   expect(Sidekiq::Queues['manage_custom_alert'].size).not_to eq(0)
      #   expect(employee.reload.last_day_worked).to eq(2.days.ago.to_date)
      #   expect(employee.reload.termination_date).to eq(2.days.ago.to_date)
      # end
    end

    context 'with GSuite account and termination date of past' do
      let(:nick){ create(:nick, email: 'nick@rship.com', company: company, gsuite_account_exists: true) }
      let!(:gsuite){ create(:gsuite_integration_instance, company: company) }

      before(:all) do
        json_string = {
          'kind': 'directory#user',
          'id': 'the unique user id',
          'primaryEmail': 'nick@rship.com',
          'isAdmin': true,
          'isDelegatedAdmin': false,
          'lastLoginTime': '2013-02-05T10:30:03.325Z',
          'creationTime': '2010-04-05T17:30:04.325Z',
          'agreedToTerms': true,
          'hashFunction': 'SHA-1',
          'suspended': false,
          'customerId': 'C03az79cb',
          'orgUnitPath': 'corp/engineering',
          'isMailboxSetup': true,
          'includeInGlobalAddressList': true
        }
        stub_request(:get, "https://www.googleapis.com/admin/directory/v1/users/nick@rship.com").to_return(body: JSON.generate(json_string), headers: {"Content-Type"=> "application/json"})
        stub_request(:patch, "https://www.googleapis.com/admin/directory/v1/users/nick@rship.com").
        with(
          body: "{\"agreedToTerms\":true,\"creationTime\":\"2010-04-05T17:30:04.325+00:00\",\"customerId\":\"C03az79cb\",\"hashFunction\":\"SHA-1\",\"id\":\"the unique user id\",\"includeInGlobalAddressList\":true,\"isAdmin\":true,\"isDelegatedAdmin\":false,\"isMailboxSetup\":true,\"kind\":\"directory#user\",\"lastLoginTime\":\"2013-02-05T10:30:03.325+00:00\",\"orgUnitPath\":\"corp/engineering\",\"primaryEmail\":\"nick@rship.com\",\"suspended\":true}",
          headers: {
          'Accept'=>'*/*',
          'Content-Type'=>'application/json',
          }).
        to_return(status: 200, body: "success", headers: {})
      end

      it 'immediately suspends users GSuite account' do
        post :offboard_user, params: { id: nick.id, last_day_worked: (nick.company.time - 2.days).to_date, termination_date: (nick.company.time - 2.days).to_date, termination_type: 0 }, format: :json
        expect(nick.reload.gsuite_account_exists).to eq(false)
      end
    end

    context "offboarding_started_webhook" do
      it "should send offboarding_started_webhook" do
        expect(Sidekiq::Queues["webhook_activities"].size).not_to eq(0)
      end
    end
  end

  describe '#update_task_date' do
    subject(:request) { post :update_task_date, params: { id: employee.id, type: 'start_date', update_termination_activities: false }, format: :json }
    before do
      task_user_connection = create(:task_user_connection, user: employee, task: task, state: 'in_progress')
      @old_start_date = employee.start_date.to_s
      employee.update!(start_date: Date.today)
    end

    context "should not update_task_date" do
      it "should return unauthorised status and doesnot invite_user for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        expect(request).to have_http_status(401)
      end

      it 'should return no content status and doesnot update_task_date for other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect(request).to have_http_status(204)
      end

      it 'should return no content status and doesnot update_task_date if current user is manager' do
        allow(controller).to receive(:current_user).and_return(nick.manager)
        expect(request).to have_http_status(204)
      end
    end

    context "should update_task_date" do
      before do
        employee.task_user_connections.take.update(before_due_date: employee.start_date)
        request
        UpdateTaskDueDateJob.perform_now(employee.id, true, false, @old_start_date, true)
      end

      it 'should return ok status and update own task_date if current user is employee ' do
        allow(controller).to receive(:current_user).and_return(employee)
        expect(employee.task_user_connections.reload.take.due_date).to eq(employee.start_date + employee.task_user_connections.take.task.deadline_in.days)
      end

      it 'should update_task_date users if current current_user is admin' do
        allow(controller).to receive(:current_user).and_return(admin)
        expect(employee.task_user_connections.reload.take.due_date).to eq(employee.start_date + employee.task_user_connections.take.task.deadline_in.days)
      end

      it 'should update_task_date if current user is super admin' do
        expect(employee.task_user_connections.reload.take.due_date).to eq(employee.start_date + employee.task_user_connections.take.task.deadline_in.days)
      end
    end
  end
end
