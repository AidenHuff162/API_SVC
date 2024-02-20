require 'rails_helper'
require 'sidekiq/testing'
RSpec.describe :UsersControllerPart4, type: :controller do
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

  describe 'POST #bulk_reassing_manager' do
    let(:company) { create(:company) }
    let(:user1) { create(:user, state: :active, current_stage: :registered, company: company) }
    let(:user2) { create(:user, state: :active, current_stage: :registered, company: company) }

    before do
      @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information])
      @data = {
        user_ids:  [user1.id, user2.id],
        effective_date: Date.today,
        manager_id: manager.id,
        is_today: true
      }
      allow(controller).to receive(:current_company).and_return(company)
      allow(controller).to receive(:current_user).and_return(super_admin)
    end

    context 'should not create bulk reassing manager custom snapshots' do
      context 'should not create bulk reassing manager custom snapshots for unauthenticated user' do
        before do
          allow(controller).to receive(:current_user).and_return(nil)
          post :bulk_reassing_manager, params: { data: @data }, format: :json
        end

        it "should return unauthorised status" do
          expect(response.status).to eq(401)
        end
      end

      context 'should not create bulk reassing manager custom snapshots for other company' do
        let(:other_company) { create(:company, subdomain: 'boo') }
        let(:other_user) { create(:user, company: other_company) }
        let(:other_superadmin) { create(:user, company: other_company, role: 'account_owner') }

        before do
          @other_user_data = {
            user_ids:  [other_user.id],
            effective_date: Date.today,
            manager_id: manager.id,
            is_today: true
          }
        end

        it 'should create no custom table user snapshot' do
          post :bulk_reassing_manager, params: { data: @other_user_data }, format: :json
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id).count).to eq(0)
        end

        it 'should create no custom table user snapshot if current super user is of other company' do
          allow(controller).to receive(:current_user).and_return(other_superadmin)
          post :bulk_reassing_manager, params: { data: @data }, format: :json
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id).count).to eq(0)
        end
      end

      context 'should not create bulk reassing manager custom snapshots as per employee permissions' do
        before do
          allow(controller).to receive(:current_user).and_return(employee)
          post :bulk_reassing_manager, params: { data: @data }, format: :json
        end

         it 'should create no custom table user snapshot' do
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id).count).to eq(0)
        end
      end

      context 'should create bulk reassing manager custom snapshots as per admin permissions' do
        before do
          allow(controller).to receive(:current_user).and_return(admin)
          post :bulk_reassing_manager, params: { data: @data }, format: :json
        end

        it 'should create custom table user snapshot' do
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id).count).to eq(2)
        end
      end

      context 'should not create bulk reassing manager custom snapshots as per manager permissions' do
        before do
          employee.update(manager_id: manager.id)
          manager.reload
          allow(controller).to receive(:current_user).and_return(manager)
          post :bulk_reassing_manager, params: { data: @data }, format: :json
        end

         it 'should create no custom table user snapshot' do
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id).count).to eq(0)
        end
      end

      context 'should not create bulk reassing manager custom snapshots if data is missing' do
        before do
          post :bulk_reassing_manager, format: :json
        end

        it 'should create no custom table user snapshot' do
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id).count).to eq(0)
        end
      end
    end

    context 'should create bulk reassign manager custom snapshots' do
      context 'should create bulk reassign manager snapshots as per super admin permissions' do
        it 'should create custom snapshot if current user is super admin' do
          post :bulk_reassing_manager, params: { data: @data }, format: :json
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id).count).not_to eq(0)
       end
      end

      context 'should create bulk reassign manager snapshots of current date having no existing snapshots of user' do
        before do
          post :bulk_reassing_manager, params: { data: @data }, format: :json
        end

        it 'should return applied state of custom table user snapshots, assigns manager to user, snapshot value to user' do
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user1.id).first.state).to eq('applied')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user2.id).first.state).to eq('applied')

          expect(user1.reload.manager_id).to eq(manager.id)
          expect(user2.reload.manager_id).to eq(manager.id)

          expect(user1.reload.manager_id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user1.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first).first.custom_field_value)
          expect(user2.reload.manager_id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user2.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first).first.custom_field_value)
        end
      end

      context 'should create bulk reassign manager snapshots of current date having past applied snapshots of user' do
        before do
          Date.stub(:today) {company.time.to_date}
          user1.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 2.days.ago.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          user2.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 2.days.ago.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          @data = {
            user_ids:  [user1.id, user2.id],
            effective_date: Date.today,
            manager_id: manager.id,
            is_today: true
          }
        post :bulk_reassing_manager, params: { data: @data }, format: :json
        end

        it 'should return applied state of custom table user snapshots, processed state of past custom table user snapshots, assign manager to user, assign snapshots value to user' do
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user1.id).second.state).to eq('applied')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user2.id).second.state).to eq('applied')

          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user1.id).first.state).to eq('processed')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user2.id).first.state).to eq('processed')

          expect(user1.reload.manager_id).to eq(manager.id)
          expect(user2.reload.manager_id).to eq(manager.id)

          expect(user1.reload.manager_id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user1.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(user2.reload.manager_id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user2.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
        end
      end

      context 'should create bulk reassign manager snapshots of past date having greater past snapshot' do
        before do
          ctus1 = user1.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 1.days.ago.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          ctus2 = user2.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 1.days.ago.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          @data = {
            user_ids:  [user1.id, user2.id],
            effective_date: 2.days.ago,
            manager_id: manager.id,
            is_today: false
          }
          post :bulk_reassing_manager, params: { data: @data }, as: :json
        end

        it 'should return applied state of custom table user snapshot, processed state of previous custom table user snapshot, not assign manager and custom snapshot value to user and create custom snapshot' do
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user1.id).second.state).to eq('processed')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user2.id).second.state).to eq('processed')

          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user1.id).first.state).to eq('applied')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user2.id).first.state).to eq('applied')

          expect(user1.reload.manager_id).not_to eq(manager.id)
          expect(user2.reload.manager_id).not_to eq(manager.id)

          expect(user1.reload.manager_id.to_s).not_to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user1.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(user2.reload.manager_id.to_s).not_to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user2.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)

          expect(manager.id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user1.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(manager.id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user2.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
        end
      end

      context 'should create bulk reassign manager snapshots of future date having past applied snapshots of user' do
        before do
          user1.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 2.days.ago.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          user2.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 2.days.ago.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          @data = {
            user_ids:  [user1.id, user2.id],
            effective_date: 3.days.from_now.to_date,
            manager_id: manager.id,
            is_today: false
          }
        post :bulk_reassing_manager, params: { data: @data }, as: :json
        end

        it 'should return queue state of future custom table user snapshots, applied state of past custom table user snapshots, not assign manager and snapshot value to user' do
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user1.id).second.state).to eq('queue')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user2.id).second.state).to eq('queue')

          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user1.id).first.state).to eq('applied')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user2.id).first.state).to eq('applied')

          expect(user1.reload.manager_id).not_to eq(manager.id)
          expect(user2.reload.manager_id).not_to eq(manager.id)

          expect(user1.reload.manager_id.to_s).not_to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user1.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(user2.reload.manager_id.to_s).not_to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user2.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)

        end
      end

      context 'should update snapshots if same future effective date and future queue snapshot date of user' do
        before do
          user1.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 2.days.ago.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          user2.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 2.days.ago.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          ctus1 = user1.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 3.days.from_now.to_date.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          ctus2 = user2.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 3.days.from_now.to_date.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          ctus1.custom_snapshots.create(preference_field_id: 'man', custom_field_value: nil)
          ctus2.custom_snapshots.create(preference_field_id: 'man', custom_field_value: nil)

          @data = {
            user_ids:  [user1.id, user2.id],
            effective_date: 3.days.from_now.to_date,
            manager_id: manager.id,
            is_today: false
          }
        post :bulk_reassing_manager, params: { data: @data }, as: :json
        end

        it 'should not create new custom table usersnapshot if effective date and queued snapshot date is same, queue state of future custom table user snapshots, applied state of past custom table user snapshots, not assign manager and snapshot value to user and update the snapshot custom field value' do
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id).count).not_to eq(6)

          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user1.id).second.state).to eq('queue')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user2.id).second.state).to eq('queue')

          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user1.id).first.state).to eq('applied')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user2.id).first.state).to eq('applied')

          expect(user1.reload.manager_id).not_to eq(manager.id)
          expect(user2.reload.manager_id).not_to eq(manager.id)

          expect(user1.reload.manager_id.to_s).not_to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user1.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(user2.reload.manager_id.to_s).not_to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user2.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)

          expect(manager.id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user1.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(manager.id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user2.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)

        end
      end

      context 'should bulk update manager if company is not using custom tables' do
        let(:company) { create(:company, is_using_custom_table: false) }

        before do
          allow(controller).to receive(:current_company).and_return(company)
          post :bulk_reassing_manager, params: { data: @data }, format: :json
        end

        it 'should assign manager to user' do
          expect(user1.reload.manager_id).to eq(manager.id)
          expect(user2.reload.manager_id).to eq(manager.id)
        end
      end
    end
  end

  describe 'POST #cancel_offboarding' do
    let(:company) { create(:company) }
    let(:offboard_user) { create(:offboarded_user, :user_with_past_snapshot, company: company) }

    before do
      @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status])
      allow(controller).to receive(:current_company).and_return(company)
      allow(controller).to receive(:current_user).and_return(super_admin)
    end

    context 'should not cancel offboarding' do
      context 'should not cancel offboarding for unauthenticated user' do
        before do
          allow(controller).to receive(:current_user).and_return(nil)
          post :cancel_offboarding, params: { id: offboard_user.id }, format: :json
        end

        it "should return unauthorised status" do
          expect(response.status).to eq(401)
        end
      end

      context 'should not cancel offboarding for other company' do
        let(:other_company) { create(:company, subdomain: 'boo') }
        let(:other_user) { create(:offboarded_user, company: other_company) }
        let(:other_superadmin) { create(:user, company: other_company) }

        it 'should create no content status' do
          post :cancel_offboarding, params: { id: other_user }, format: :json
          expect(response.status).to eq(204)
        end

        it 'should create no content status' do
          allow(controller).to receive(:current_user).and_return(other_superadmin)
          post :cancel_offboarding, params: { id: offboard_user.id }, format: :json
          expect(response.status).to eq(204)
        end
      end

      context 'should not cancel offboarding as per employee permission' do
        before do
          allow(controller).to receive(:current_user).and_return(employee)
          post :cancel_offboarding, params: { id: employee.id }, format: :json
        end

         it 'should create no content status' do
          expect(response.status).to eq(204)
        end
      end

      context 'should not cancel offboarding as per manager permission' do
        before do
          employee.update(manager_id: manager.id)
          manager.reload
          allow(controller).to receive(:current_user).and_return(manager)
          post :cancel_offboarding, params: { id: manager.id }, format: :json
        end

         it 'should create no content status' do
          expect(response.status).to eq(204)
        end
      end

      context 'should not cancel offboarding of own' do
        before do
          post :cancel_offboarding, params: { id: super_admin.id }, format: :json
        end

         it 'should create no content status' do
          expect(response.status).to eq(204)
        end
      end
    end

    context 'should cancel offboarding' do
      context 'should cancel offboarding as per admin permissions' do
        before do
          allow(controller).to receive(:current_user).and_return(admin)
          post :cancel_offboarding, params: { id: offboard_user.id }, format: :json
        end

         it 'should create ok status' do
          expect(response.status).to eq(200)
        end
      end

      context 'should cancel offboarding as per super admin permissions' do
        before do
          allow(controller).to receive(:current_user).and_return(super_admin)
          post :cancel_offboarding, params: { id: offboard_user.id }, format: :json
        end

         it 'should create ok status' do
          expect(response.status).to eq(200)
        end
      end

      context 'should cancel offboarding if user is not rehired' do
        before do
          custom_field = company.custom_fields.find_by(name: 'Employment Status')
          custom_field_option = custom_field.custom_field_options.find_by(option: 'Full Time')
          offboard_user.custom_field_values.create(custom_field_id: custom_field.id, custom_field_option_id: custom_field_option.id)
          post :cancel_offboarding, params: { id: offboard_user.id }, format: :json
        end

         it 'should return ok status, change current stage to registered, current state to active, termination date to nil, termination type to nil, last day worked to nil, eligible_for_rehire to nil and destroy employment status terminated ctus, not change is rehired to true, not reset user employment status, return terminated employment status' do
          expect(response.status).to eq(200)
          expect(offboard_user.reload.current_stage).to eq('first_month')
          expect(offboard_user.reload.state).to eq('active')
          expect(offboard_user.reload.termination_date).to eq(nil)
          expect(offboard_user.reload.termination_type).to eq(nil)
          expect(offboard_user.reload.last_day_worked).to eq(nil)
          expect(offboard_user.reload.eligible_for_rehire).to eq(nil)
          expect(offboard_user.reload.is_rehired?).not_to eq(true)
          expect(offboard_user.reload.employee_type).not_to eq(nil)
          expect(offboard_user.reload.employee_type).to eq('Full Time')
        end
      end

      context 'should cancel offboarding if user is rehired' do
        before do
          custom_field = company.custom_fields.find_by(name: 'Employment Status')
          custom_field_option = custom_field.custom_field_options.find_by(option: 'Full Time')
          offboard_user.custom_field_values.create(custom_field_id: custom_field.id, custom_field_option_id: custom_field_option.id)
          post :cancel_offboarding, params: { id: offboard_user.id, is_rehired: true }, format: :json
        end

         it 'should return ok status, change current stage to invited, current state to active, termination date to nil, termination type to nil, last day worked to nil, eligible_for_rehire to nil, is rehired to true, destroy employment status terminated ctus, reset employment status' do
          expect(response.status).to eq(200)
          expect(offboard_user.reload.current_stage).to eq('departed')
          expect(offboard_user.reload.state).to eq('active')
          expect(offboard_user.reload.termination_date).to eq(nil)
          expect(offboard_user.reload.termination_type).to eq(nil)
          expect(offboard_user.reload.last_day_worked).to eq(nil)
          expect(offboard_user.reload.eligible_for_rehire).to eq(nil)
          expect(offboard_user.reload.is_rehired?).to eq(true)
          expect(offboard_user.reload.employee_type).to eq('Full Time')
        end
      end

      context 'should cancel offboarding if user is rehired and company is not using custom table' do
        let(:company) { create(:company, is_using_custom_table: false) }
        let(:offboard_user) { create(:offboarded_user, company: company) }

        before do
          allow(controller).to receive(:current_company).and_return(company)
          custom_field = company.custom_fields.find_by(name: 'Employment Status')
          custom_field_option = custom_field.custom_field_options.find_by(option: 'Full Time')
          offboard_user.custom_field_values.create(custom_field_id: custom_field.id, custom_field_option_id: custom_field_option.id)
          post :cancel_offboarding, params: { id: offboard_user.id, is_rehired: true }, format: :json
        end

         it 'should return ok status, change current stage to invited, current state to active, termination date to nil, termination type to nil, last day worked to nil, eligible_for_rehire to nil, is rehired to true, reset employment status' do
          expect(response.status).to eq(200)
          expect(offboard_user.reload.current_stage).to eq('departed')
          expect(offboard_user.reload.state).to eq('active')
          expect(offboard_user.reload.termination_date).to eq(nil)
          expect(offboard_user.reload.termination_type).to eq(nil)
          expect(offboard_user.reload.last_day_worked).to eq(nil)
          expect(offboard_user.reload.eligible_for_rehire).to eq(nil)
          expect(offboard_user.reload.is_rehired?).to eq(true)
          expect(offboard_user.reload.employee_type).to eq('Full Time')
        end
      end

      context 'should cancel offboarding if user is not rehired and company is not using custom table' do
        let(:company) { create(:company, is_using_custom_table: false) }
        let(:offboard_user) { create(:offboarded_user, company: company) }

        before do
          allow(controller).to receive(:current_company).and_return(company)
          custom_field = company.custom_fields.find_by(name: 'Employment Status')
          custom_field_option = custom_field.custom_field_options.find_by(option: 'Full Time')
          offboard_user.custom_field_values.create(custom_field_id: custom_field.id, custom_field_option_id: custom_field_option.id)
          post :cancel_offboarding, params: { id: offboard_user.id }, format: :json
        end

         it 'should return ok status, current stage to registered, state to active, termination date to nil, termination type to nil, last day worked to nil, eligible_for_rehire to nil, not change is rehired to true, user employment status, return terminated employment status' do
          expect(response.status).to eq(200)
          expect(offboard_user.reload.current_stage).to eq('first_month')
          expect(offboard_user.reload.state).to eq('active')
          expect(offboard_user.reload.termination_date).to eq(nil)
          expect(offboard_user.reload.termination_type).to eq(nil)
          expect(offboard_user.reload.last_day_worked).to eq(nil)
          expect(offboard_user.reload.eligible_for_rehire).to eq(nil)
          expect(offboard_user.reload.is_rehired?).not_to eq(true)
          expect(offboard_user.reload.employee_type).not_to eq(nil)
          expect(offboard_user.reload.employee_type).to eq('Full Time')
        end
      end
    end

     context "offboarding_cancelled_webhook" do
      it "should send_offboarding_cancelled_webhook" do
        expect(Sidekiq::Queues["webhook_activities"].size).not_to eq(0)
      end
    end
  end

  describe 'POST #create_rehired_user_snapshots' do
    let(:company) { create(:company, subdomain: 'rehire') }

     before do
      allow(controller).to receive(:current_company).and_return(company)
      allow(controller).to receive(:current_user).and_return(super_admin)
    end

    context 'should not create rehired custom snapshots' do
      context 'should not create rehired custom snapshots for unauthenticated user' do
        before do
          allow(controller).to receive(:current_user).and_return(nil)
          post :create_rehired_user_snapshots, params: { id: super_admin.id }, format: :json
        end

        it "should return unauthorised status" do
          expect(response.status).to eq(401)
        end
      end

      context 'should not create rehired custom snapshots for other company' do
        let(:other_company) { create(:company, subdomain: 'boo') }
        let(:other_user) { create(:user, company: other_company) }

        it 'should return no content status' do
          post :create_rehired_user_snapshots, params: { id: other_user.id }, format: :json
          expect(response.status).to eq(204)
        end

        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(other_user)
          post :create_rehired_user_snapshots, params: { id: other_user.id }, format: :json
          expect(response.status).to eq(204)
        end
      end

      context 'should not create rehired custom snapshots as per manager permission' do
        before do
          employee.update(manager_id: manager.id)
          manager.reload
          allow(controller).to receive(:current_user).and_return(manager)
          post :create_rehired_user_snapshots, params: { id: employee.id }, format: :json
        end

        it "should return no context status" do
          expect(response.status).to eq(204)
        end
      end

      context 'should not create rehired custom snapshots as per employee permission' do
        before do
          allow(controller).to receive(:current_user).and_return(employee)
          post :create_rehired_user_snapshots, params: { id: employee.id }, format: :json
        end

        it "should return forbidden status" do
          expect(response.status).to eq(204)
        end
      end

      context 'should not create rehired custom snapshots of own' do
        before do
          post :create_rehired_user_snapshots, params: { id: super_admin.id }, format: :json
        end

        it "should return forbidden status" do
          expect(response.status).to eq(204)
        end
      end
    end

    context 'should create rehired custom snapshots' do
      let(:rehire_user) { create(:rehire_user, :user_with_past_snapshot, manager: user, location: location, team: team, role: User.roles[:employee], company: company) }

      context 'should create rehired custom snapshots as per super admin permission' do
        before do
          post :create_rehired_user_snapshots, params: { id: employee.id }, format: :json
        end

        it "should return ok status" do
          expect(response.status).to eq(200)
        end
      end

      context 'should create rehired custom snapshots as per admin permission' do
        before do
          allow(controller).to receive(:current_user).and_return(admin)
          post :create_rehired_user_snapshots, params: { id: employee.id }, format: :json
        end

        it "should return ok status" do
          expect(response.status).to eq(200)
        end
      end

      context 'should create role information custom snapshots' do
        before do
          @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information])
          @custom_fields = @custom_table.custom_fields
          post :create_rehired_user_snapshots, params: { id: rehire_user.id }, format: :json
        end

        it "should return ok status, applied state of custom table user snapshot" do
          expect(response.status).to eq(200)
          expect(rehire_user.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.state).to eq('applied')
        end

        it 'should change state of previous snapshot to processed and is_applicable to false' do
          expect(rehire_user.custom_table_user_snapshots.where(is_applicable: false, state: CustomTableUserSnapshot.states[:processed]).count).to eq(1)
        end

        context 'should assign custom field custom snapshot value' do
          it 'should assign effective date value to user, effective date value is equal to user start date, assign custom field custom snapshot value to user' do
            custom_field = @custom_fields.find_by(name: 'Effective Date')
            snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: rehire_user.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
            expect(rehire_user.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value.to_date.to_s)
            expect(rehire_user.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(rehire_user.start_date.to_s)

            @custom_fields.each do |custom_field|
              if custom_field.name != 'Effective Date'
                snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: rehire_user.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
                expect(rehire_user.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value)
              end
            end
          end
        end

        context 'should assign preference fields custom snapshot value to user' do
           it 'should assign manager, title, department, location to user' do
            snapshot_value = CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: rehire_user.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
            expect(rehire_user.manager_id).to eq(snapshot_value.to_i)
            expect(rehire_user.title).to eq(CustomSnapshot.where(preference_field_id: 'jt', custom_table_user_snapshot_id: rehire_user.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value)
            expect(rehire_user.team_id).to eq(CustomSnapshot.where(preference_field_id: 'dpt', custom_table_user_snapshot_id: rehire_user.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value.to_i)
            expect(rehire_user.location_id).to eq(CustomSnapshot.where(preference_field_id: 'loc', custom_table_user_snapshot_id: rehire_user.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value.to_i)
          end
        end
      end

      context 'should create employment status custom snapshots' do
        before do
          @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status])
          @custom_fields = @custom_table.custom_fields
          @custom_fields.each do |custom_field|
            if custom_field.field_type == 'employment_status'
              rehire_user.custom_field_values << create(:custom_field_value, custom_field: custom_field, custom_field_option_id: custom_field.custom_field_options.find_by(option: 'Full Time').try(:id))
            elsif custom_field.name != 'Effective Date'
              rehire_user.custom_field_values << create(:custom_field_value, custom_field: custom_field)
            end
          end
          post :create_rehired_user_snapshots, params: { id: rehire_user.id }, format: :json
        end

        it "should return ok status and applied state of custom table user snapshot" do
          expect(response.status).to eq(200)
          ctus = rehire_user.custom_table_user_snapshots.find_by(custom_table_id: @custom_table.id, is_applicable: true, state: CustomTableUserSnapshot.states[:applied])
          expect(ctus.state).to eq('applied')
        end

        it 'should change state of previous snapshot to processed and is_applicable to false' do
          expect(rehire_user.custom_table_user_snapshots.where(is_applicable: false, state: CustomTableUserSnapshot.states[:processed]).count).to eq(1)
        end

        context 'should assign custom field custom snapshot value' do
          it 'should assign effective date value to user and effective date value is equal to user start date and assign custom field custom snapshot value to user and assign employment status custom snapshot value to user' do
            custom_field = @custom_fields.find_by(name: 'Effective Date')
            ctus_id = rehire_user.custom_table_user_snapshots.find_by(custom_table_id: @custom_table.id, is_applicable: true, state: CustomTableUserSnapshot.states[:applied]).id
            snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: ctus_id).first.custom_field_value
            expect(rehire_user.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value.to_date.to_s)
            expect(rehire_user.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(rehire_user.start_date.to_s)

            @custom_fields.each do |custom_field|
              if custom_field.name != 'Effective Date' && custom_field.field_type != 'employment_status'
                ctus_id = rehire_user.custom_table_user_snapshots.find_by(custom_table_id: @custom_table.id, is_applicable: true, state: CustomTableUserSnapshot.states[:applied]).id
                snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: ctus_id).first.custom_field_value
                expect(rehire_user.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value)
              end
            end

            custom_field = @custom_fields.find_by(field_type: 13)
            ctus_id = rehire_user.custom_table_user_snapshots.find_by(custom_table_id: @custom_table.id, is_applicable: true, state: CustomTableUserSnapshot.states[:applied]).id
            snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: ctus_id).first.custom_field_value
            expect(rehire_user.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value.to_i)
          end
        end

        context 'should assign preference fields custom snapshot value to user' do
          it 'should assign manager value to user' do
            ctus_id = rehire_user.custom_table_user_snapshots.find_by(custom_table_id: @custom_table.id, is_applicable: true, state: CustomTableUserSnapshot.states[:applied]).id
            snapshot_value = CustomSnapshot.where(preference_field_id: 'st', custom_table_user_snapshot_id: ctus_id).first.custom_field_value
            expect(rehire_user.state).to eq(snapshot_value)
          end
        end
      end

      context 'should create compensation custom snapshots' do
        before do
          @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:compensation])
          @custom_fields = @custom_table.custom_fields
          @custom_fields.each do |custom_field|
            if custom_field.field_type == 'currency'
              rehire_user.custom_field_values << create(:custom_field_value, sub_custom_field: custom_field.sub_custom_fields.first, value_text: 'USD')
              rehire_user.custom_field_values << create(:custom_field_value, sub_custom_field: custom_field.sub_custom_fields.second, value_text: '200')
            elsif custom_field.name != 'Effective Date'
              rehire_user.custom_field_values << create(:custom_field_value, custom_field: custom_field)
            end
          end
          post :create_rehired_user_snapshots, params: { id: rehire_user.id }, format: :json
        end

        it "should return ok status and applied state of custom table user snapshot" do
          expect(response.status).to eq(200)
          expect(rehire_user.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.state).to eq('applied')
        end

        it 'should change state of previous snapshot to processed and is_applicable to false' do
          expect(rehire_user.custom_table_user_snapshots.where(is_applicable: false, state: CustomTableUserSnapshot.states[:processed]).count).to eq(1)
        end

        context 'should assign custom field custom snapshot value' do
          it 'should assign effective date value to user and effective date value is equal to user start date and assign custom fields custom snapshot value to user' do
            custom_field = @custom_fields.find_by(name: 'Effective Date')
            snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: rehire_user.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
            expect(rehire_user.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value.to_date.to_s)
            expect(rehire_user.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(rehire_user.start_date.to_s)

            custom_field = @custom_fields.find_by(field_type: 14)
            expect(rehire_user.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: rehire_user.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value)

            @custom_fields.each do |custom_field|
              if custom_field.name != 'Effective Date' && custom_field.field_type != 'currency'
                snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: rehire_user.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).first.id).first.custom_field_value
                expect(rehire_user.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value)
              end
            end
          end
        end
      end
    end
  end

  describe 'PUT #update to check ADP integration' do
    context 'can make ADP-US update call' do

      before do
        create(:adp_wfn_us_integration, company: company)
        @adp_us_user = create(:user, state: :active, current_stage: :registered, company: company)
        @adp_us_user.update_column(:adp_wfn_us_id, 123)

      end

      it 'should make update call for first name change' do
        expect{
          put :update, params: {id: @adp_us_user.id, first_name: 'Test'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for last name change' do
        expect{
          put :update, params: {id: @adp_us_user.id, last_name: 'Test'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for preferred name change' do
        expect{
          put :update, params: {id: @adp_us_user.id, preferred_name: 'Test'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for personal email change' do
        expect{
          put :update, params: {id: @adp_us_user.id, personal_email: 'testadpus@test.com'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for email change' do
        expect{
          put :update, params: {id: @adp_us_user.id, email: 'testadpus@test.com'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for title change' do
        expect{
          put :update, params: {id: @adp_us_user.id, title: 'SE'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end
    end

    context 'can make ADP-CAN update call' do

      before do
        create(:adp_wfn_can_integration, company: company)
        @adp_can_user = create(:user, state: :active, current_stage: :registered, company: company)
        @adp_can_user.update_column(:adp_wfn_can_id, 123)

      end

      it 'should make update call for first name change' do
        expect{
          put :update, params: {id: @adp_can_user.id, first_name: 'Test'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for last name change' do
        expect{
          put :update, params: {id: @adp_can_user.id, last_name: 'Test'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for preferred name change' do
        expect{
          put :update, params: {id: @adp_can_user.id, preferred_name: 'Test'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for personal email change' do
        expect{
          put :update, params: {id: @adp_can_user.id, personal_email: 'testadpus@test.com'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for email change' do
        expect{
          put :update, params: {id: @adp_can_user.id, email: 'testadpus@test.com'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end

      it 'should make update call for title change' do
        expect{
          put :update, params: {id: @adp_can_user.id, title: 'SE'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(1)
      end
    end

    context 'can not make ADP update call' do

      before do
        @adp_can_user = create(:user, state: :active, current_stage: :registered, company: company)
        @adp_can_user.update_column(:adp_wfn_can_id, 123)

      end

      it 'should make update call for first name change' do
        expect{
          put :update, params: {id: @adp_can_user.id, first_name: 'Test'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(0)
      end

      it 'should make update call for last name change' do
        expect{
          put :update, params: {id: @adp_can_user.id, last_name: 'Test'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(0)
      end

      it 'should make update call for preferred name change' do
        expect{
          put :update, params: {id: @adp_can_user.id, preferred_name: 'Test'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(0)
      end

      it 'should make update call for personal email change' do
        expect{
          put :update, params: {id: @adp_can_user.id, personal_email: 'testadpus@test.com'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(0)
      end

      it 'should make update call for email change' do
        expect{
          put :update, params: {id: @adp_can_user.id, email: 'testadpus@test.com'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(0)
      end

      it 'should make update call for title change' do
        expect{
          put :update, params: {id: @adp_can_user.id, title: 'SE'}, as: :json
        }.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(0)
      end
    end
  end

  describe 'POST #reassign_manager_offboard_custom_snapshots' do
    let(:company) { create(:company) }

    before do
      allow(controller).to receive(:current_company).and_return(company)
      allow(controller).to receive(:current_user).and_return(super_admin)
    end

    context 'should not create reassign manager offboard custom snapshots' do
      context 'should not create reassign manager offboard custom snapshots for unauthenticated user' do
        before do
          allow(controller).to receive(:current_user).and_return(nil)
          post :reassign_manager_offboard_custom_snapshots, params: { id: super_admin.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return unauthorised status" do
          expect(response.status).to eq(401)
        end
      end

      context 'should not create reassign manager offboard custom snapshots for other company' do
        let(:other_company) { create(:company, subdomain: 'boo') }
        let(:other_user) { create(:user, company: other_company) }

       it 'should return no content status for other company user' do
          post :reassign_manager_offboard_custom_snapshots, params: { id: other_user.id, sub_tab: 'dashboard' }, format: :json
          expect(response.status).to eq(204)
        end

        it 'should return no content status if current user is of other company' do
          allow(controller).to receive(:current_user).and_return(other_user)
          post :reassign_manager_offboard_custom_snapshots, params: { id: other_user.id, sub_tab: 'dashboard' }, format: :json
          expect(response.status).to eq(204)
        end
      end

      context 'should create reassign manager offboard custom snapshots if super admin has no dashboard access' do
        before do
          disable_dashboard_access(super_admin.user_role)
          post :reassign_manager_offboard_custom_snapshots, params: { id: employee.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return no content status" do
          expect(response.status).to eq(200)
        end
      end

      context 'should not create reassign manager offboard custom snapshots if admin has no dashboard access' do
        before do
          disable_dashboard_access(admin.user_role)
          allow(controller).to receive(:current_user).and_return(admin)
          post :reassign_manager_offboard_custom_snapshots, params: { id: employee.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return no content status" do
          expect(response.status).to eq(204)
        end
      end

      context 'should not create reassign manager offboard custom snapshots as per manager permission' do
        before do
          employee.update(manager_id: manager.id)
          manager.reload
          allow(controller).to receive(:current_user).and_return(manager)
          post :reassign_manager_offboard_custom_snapshots, params: { id: employee.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return no context status" do
          expect(response.status).to eq(204)
        end
      end

      context 'should not create reassign manager offboard custom snapshots as per employee permission' do
        before do
          allow(controller).to receive(:current_user).and_return(employee)
          post :reassign_manager_offboard_custom_snapshots, params: { id: employee.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return forbidden status" do
          expect(response.status).to eq(204)
        end
      end

      context 'should not create manager offboard custom snapshots if employee data is missing' do
        before do
          post :reassign_manager_offboard_custom_snapshots, params: { id: employee.id, sub_tab: 'dashboard' }, format: :json
          @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information])
        end
        it 'should create no role information custom table user snapshot' do
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id).count).to eq(0)
        end
      end
    end

    context 'should create reassign manager offboard custom snapshots' do
      let(:offboard_user) { create(:offboarded_user, company: company) }
      let(:user1) { create(:user, state: :active, current_stage: :registered, company: company, manager_id: offboard_user.id) }
      let(:user2) { create(:user, state: :active, current_stage: :registered, company: company, manager_id: offboard_user.id) }
      let(:user3) { create(:user, state: :active, current_stage: :registered, company: company, manager_id: offboard_user.id) }

      context 'should create reassign manager offboard custom snapshots if sub tab is not present' do
        before do
          post :reassign_manager_offboard_custom_snapshots, params: { user_id: offboard_user.id }, format: :json
        end

        it "should return ok status" do
          expect(response.status).to eq(200)
        end
      end

      context 'should create reassign manager offboard custom snapshots as per super admin permission' do
        before do
          post :reassign_manager_offboard_custom_snapshots, params: { user_id: offboard_user.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return ok status" do
          expect(response.status).to eq(200)
        end
      end

      context 'should create reassign manager offboard custom snapshots as per admin permission' do
        before do
          allow(controller).to receive(:current_user).and_return(admin)
          post :reassign_manager_offboard_custom_snapshots, params: { user_id: offboard_user.id, sub_tab: 'dashboard' }, format: :json
        end

        it "should return ok status" do
          expect(response.status).to eq(200)
        end
      end

      context 'should create reassign manager snapshots of past offboard user' do
        before do
          employee_data_array = [
            {"user_id" => user1.id, "manager_id" => manager.id, "terminated_user_id" => offboard_user.id},
            {"user_id" => user2.id, "manager_id" => manager.id, "terminated_user_id" => offboard_user.id},
            {"user_id" => user3.id, "manager_id" => manager.id, "terminated_user_id" => offboard_user.id}
          ]

          @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information])
          user1.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 4.days.ago.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          user2.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 4.days.ago.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          user3.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 4.days.ago.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          Sidekiq::Testing.inline! do
            post :reassign_manager_offboard_custom_snapshots, params: { user_id: offboard_user.id, sub_tab: 'dashboard', data: employee_data_array }, format: :json
          end
        end

        it "should return ok status, applied state of custom table user snapshot, processed state of previous custom table user snapshot, assign manager to user and assign custom snapshot value to user and create custom snapshot" do
          expect(response.status).to eq(200)
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user1.id).second.state).to eq('applied')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user2.id).second.state).to eq('applied')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user3.id).second.state).to eq('applied')

          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user1.id).first.state).to eq('processed')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user2.id).first.state).to eq('processed')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user3.id).first.state).to eq('processed')

          expect(user1.reload.manager_id).to eq(manager.id)
          expect(user2.reload.manager_id).to eq(manager.id)
          expect(user2.reload.manager_id).to eq(manager.id)

          expect(user1.reload.manager_id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user1.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(user2.reload.manager_id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user2.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(user3.reload.manager_id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user3.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)

          expect(manager.id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user1.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(manager.id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user2.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(manager.id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user3.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
        end
      end

      context 'should create reassign manager snapshots of past offboard user having past applied snaphot date greater than termination date' do
        before do
          employee_data_array = [
            {"user_id" => user1.id, "manager_id" => manager.id, "terminated_user_id" => offboard_user.id},
            {"user_id" => user2.id, "manager_id" => manager.id, "terminated_user_id" => offboard_user.id},
            {"user_id" => user3.id, "manager_id" => manager.id, "terminated_user_id" => offboard_user.id}
          ]

          @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information])
          user1.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 1.days.ago.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          user2.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 1.days.ago.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          user3.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 1.days.ago.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])

          post :reassign_manager_offboard_custom_snapshots, params: { user_id: offboard_user.id, sub_tab: 'dashboard', data: employee_data_array }, format: :json
        end

        it "should return ok state, applied state of custom table user snapshot, processed state of previous custom table user snapshot, not assign manager to user, not assign custom snapshot value to user, create custom snapshot" do
          expect(response.status).to eq(200)

          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user1.id).second.state).to eq('processed')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user2.id).second.state).to eq('processed')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user3.id).second.state).to eq('processed')

          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user1.id).first.state).to eq('applied')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user2.id).first.state).to eq('applied')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user3.id).first.state).to eq('applied')

          expect(user1.reload.manager_id).not_to eq(manager.id)
          expect(user2.reload.manager_id).not_to eq(manager.id)
          expect(user2.reload.manager_id).not_to eq(manager.id)

          expect(user1.reload.manager_id.to_s).not_to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user1.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(user2.reload.manager_id.to_s).not_to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user2.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(user3.reload.manager_id.to_s).not_to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user3.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)

          expect(manager.id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user1.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(manager.id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user2.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(manager.id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user3.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
        end
      end

      context 'should create reassign manager snapshots of future offboard user' do
        let(:future_offboard_user) { create(:offboarded_user, termination_date: 1.days.from_now, current_stage: :last_week, company: company, last_day_worked: 1.days.from_now) }
        let(:user1) { create(:user, state: :active, current_stage: :registered, company: company, manager_id: future_offboard_user.id) }
        let(:user2) { create(:user, state: :active, current_stage: :registered, company: company, manager_id: future_offboard_user.id) }
        let(:user3) { create(:user, state: :active, current_stage: :registered, company: company, manager_id: future_offboard_user.id) }

        before do
          @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information])
          user1.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 2.days.ago.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          user2.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 2.days.ago.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          user3.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: 2.days.ago.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          employee_data_array = [
            {"user_id" => user1.id, "manager_id" => manager.id, "terminated_user_id" => future_offboard_user.id},
            {"user_id" => user2.id, "manager_id" => manager.id, "terminated_user_id" => future_offboard_user.id},
            {"user_id" => user3.id, "manager_id" => manager.id, "terminated_user_id" => future_offboard_user.id}
          ]

          post :reassign_manager_offboard_custom_snapshots, params: { user_id: future_offboard_user.id, sub_tab: 'dashboard', data: employee_data_array }, format: :json
        end

        it "should return ok state, queued state of latest ctus, applied state of past custom table user snapshot, not assign manager and custom snapshot value to user, create custom snapshot and previous manager assigned to user" do
          expect(response.status).to eq(200)

          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user1.id).second.state).to eq('queue')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user2.id).second.state).to eq('queue')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user3.id).second.state).to eq('queue')

          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user1.id).first.state).to eq('applied')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user2.id).first.state).to eq('applied')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user3.id).first.state).to eq('applied')

          expect(user1.reload.manager_id).not_to eq(manager.id)
          expect(user2.reload.manager_id).not_to eq(manager.id)
          expect(user2.reload.manager_id).not_to eq(manager.id)

          expect(user1.reload.manager_id.to_s).not_to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user1.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(user2.reload.manager_id.to_s).not_to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user2.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(user3.reload.manager_id.to_s).not_to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user3.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)

          expect(manager.id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user1.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(manager.id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user2.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(manager.id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user3.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)

          expect(future_offboard_user.id).to eq(user1.reload.manager_id)
          expect(future_offboard_user.id).to eq(user2.reload.manager_id)
          expect(future_offboard_user.id).to eq(user3.reload.manager_id)

        end
      end

      context 'should create reassign manager snapshots of current date offboard user' do
        let(:offboard_user_with_current_date) { create(:offboarded_user, termination_date: Time.now.in_time_zone(company.time_zone).to_date, current_stage: :last_week, company: company, last_day_worked: Time.now.in_time_zone(company.time_zone).to_date) }
        let(:user1) { create(:user, state: :active, current_stage: :registered, company: company, manager_id: offboard_user_with_current_date.id) }
        let(:user2) { create(:user, state: :active, current_stage: :registered, company: company, manager_id: offboard_user_with_current_date.id) }
        let(:user3) { create(:user, state: :active, current_stage: :registered, company: company, manager_id: offboard_user_with_current_date.id) }

        before do
          employee_data_array = [
            {"user_id" => user1.id, "manager_id" => manager.id, "terminated_user_id" => offboard_user_with_current_date.id},
            {"user_id" => user2.id, "manager_id" => manager.id, "terminated_user_id" => offboard_user_with_current_date.id},
            {"user_id" => user3.id, "manager_id" => manager.id, "terminated_user_id" => offboard_user_with_current_date.id}
          ]
          @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information])
          user1.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: Time.now.in_time_zone(company.time_zone).to_date, terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          user2.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: Time.now.in_time_zone(company.time_zone).to_date, terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          user3.custom_table_user_snapshots.create(custom_table_id: @custom_table.id, effective_date: Time.now.in_time_zone(company.time_zone).to_date, terminate_job_execution: true, edited_by_id: super_admin.id, state: CustomTableUserSnapshot.states[:queue])
          Sidekiq::Testing.inline! do
            post :reassign_manager_offboard_custom_snapshots, params: { user_id: offboard_user_with_current_date.id, sub_tab: 'dashboard', data: employee_data_array }, format: :json
          end
        end

        it "should return ok state and applied state of latest ctus, processed state of previous cuurent date, assign manager and custom snapshot value to user and create custom snapshot" do
          expect(response.status).to eq(200)

          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user1.id).second.state).to eq('applied')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user2.id).second.state).to eq('applied')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user3.id).second.state).to eq('applied')

          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user1.id).first.state).to eq('processed')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user2.id).first.state).to eq('processed')
          expect(CustomTableUserSnapshot.where(custom_table_id: @custom_table.id, user_id: user3.id).first.state).to eq('processed')

          expect(user1.reload.manager_id).to eq(manager.id)
          expect(user2.reload.manager_id).to eq(manager.id)
          expect(user3.reload.manager_id).to eq(manager.id)

          expect(user1.reload.manager_id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user1.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(user2.reload.manager_id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user2.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(user3.reload.manager_id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user3.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)

          expect(manager.id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user1.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(manager.id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user2.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)
          expect(manager.id.to_s).to eq(CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: user3.custom_table_user_snapshots.where(custom_table_id: @custom_table.id).second).first.custom_field_value)

        end
      end
    end
  end
end
