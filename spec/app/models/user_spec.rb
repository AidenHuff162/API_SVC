require 'rails_helper'

RSpec.describe User, type: :model do
  subject(:company) {FactoryGirl.create(:company, notifications_enabled: true, preboarding_complete_emails: true, enabled_time_off: true)}
  let(:xero_integration_inventory) {create(:integration_inventory, display_name: 'Xero', status: 2, category: 0, data_direction: 1, enable_filters: false, api_identifier: 'xero')}
  let(:xero) {create(:integration_instance, api_identifier: 'xero', state: 'active', integration_inventory_id: xero_integration_inventory.id, name: 'Instance no.1', company_id: company.id)}
  subject(:sarah) {FactoryGirl.create(:sarah, company: company)}
  subject(:tim) {FactoryGirl.create(:tim, is_current_stage_changed: true, company: company)}
  subject(:nick) {FactoryGirl.create(:nick, manager_id: sarah.id)}
  let(:user_email) { create(:user_email, user: nick) }
  subject(:invited_user) {FactoryGirl.create(:invite, user_email: user_email).user_email.user}
  subject(:user) { create(:user_with_tasks) }
  before { SidekiqUniqueJobs.config.enabled = false }

  describe 'Associations' do
    it { is_expected.to belong_to(:company).counter_cache }
    it { is_expected.to belong_to(:location) }
    it { is_expected.to belong_to(:team) }
    it { is_expected.to belong_to(:manager) }
    it { is_expected.to have_many(:teams).dependent(:nullify) }
    it { is_expected.to have_many(:calendar_events).dependent(:destroy) }
    it { is_expected.to have_many(:locations).dependent(:nullify) }
    it { is_expected.to have_many(:all_managed_users).dependent(:nullify) }
    it { is_expected.to have_many(:invites).dependent(:destroy) }
    it { is_expected.to have_one(:owned_company) }
    it { is_expected.to have_many(:task_user_connections) }
    it { is_expected.to have_one(:profile_image).dependent(:destroy) }
    it { is_expected.to have_one(:profile).dependent(:destroy) }
    it { is_expected.to have_many(:created_webhooks).class_name('Webhook').with_foreign_key(:created_by_id).dependent(:nullify) }
    it { is_expected.to have_many(:updated_webhooks).class_name('Webhook').with_foreign_key(:updated_by_id).dependent(:nullify) }
    it { is_expected.to have_many(:webhook_events).class_name('WebhookEvent').with_foreign_key(:triggered_for_id).dependent(:nullify) }
    it { is_expected.to have_many(:triggered_webhook_events).class_name('WebhookEvent').with_foreign_key(:triggered_by_id).dependent(:nullify) }
    it { is_expected.to have_many(:sftps).with_foreign_key(:updated_by_id).dependent(:nullify) }
  end

  describe 'model_callbacks' do
  	context 'before_destroy' do
      it { should callback(:free_manager_role).before(:destroy) }
      it { should callback(:auto_denny_related_pto_requests).before(:destroy) }
      it { should callback(:nullify_accounnt_creator_id).before(:destroy) }
      it { should callback(:destroy_pre_start_email_jobs).before(:destroy) }
      it { should callback(:update_comments_description_for_mentioned_users).before(:destroy) }
      it { should callback(:expire_cache).before(:destroy) }
      it { should callback(:expire_cache).before(:destroy) }
  		context 'user mentioned comments' do
  		  let(:nick){ create(:nick, email: 'nicktestemail@mail.com', personal_email: 'nickemailtest@mail.com', company: company) }
  			let(:user){ create(:user, company: company) }
  			let(:workstream){ create(:workstream, company: company) }
  			let(:task){ create(:task, workstream: workstream) }
  			let(:task_user_connection){ create(:task_user_connection, task: task, user: user, agent_id: user.id) }
  			before do
  				@comment = build(:comment, description: "hey, USERTOKEN[#{user.id}] how are you", commentable_id: task_user_connection.id, commentable_type: 'TaskUserConnection', commenter: nick, company: company)
    			@comment.mentioned_users << user.id.to_s
    			@comment.save
    			@first_name = user.first_name
    			@user_token = "USERTOKEN[#{user.id}]"
  		 		user.destroy
  			end
  		 	it 'should change the description of the comment' do
  		 		expect(@comment.reload.description).to include("@#{@first_name}")
  		 	end
  		 	it 'should not include the tokenised value for deleted user' do
  		 		expect(@comment.reload.description).to_not include(@user_token)
  		 	end
  		end

      context 'auto_denny_related_pto_requests' do
        let(:nick){ create(:user_with_manager_and_policy, company: company, start_date: Date.today - 1.year) }
        before { User.current = nick}
        it 'should deny manged user requests' do
          pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id, status: 0)
          nick.manager.destroy
          expect(pto_request.reload.status).to eq('denied')
        end
      end

      context 'free_manager_role' do
        let(:nick){ create(:nick, company: company) }
        it 'should free manager role for manager' do
          manager = nick.manager
          manager.reload
          nick.destroy
          expect(manager.reload.user_role.role_type).to eq('employee')
        end
      end

      context 'nullify_accounnt_creator_id' do
        let(:nick){ create(:nick, company: company) }
        let(:temp_user) {FactoryGirl.create(:user, company: company, account_creator_id: nick.manager_id, buddy_id: nick.manager_id, created_by_id: nick.manager_id)}
        it 'should nullify creator, manager, buddy ids' do
          nick.manager.destroy
          expect(nick.reload.manager_id).to eq(nil)
          expect(temp_user.reload.account_creator_id).to eq(nil)
          expect(temp_user.reload.buddy_id).to eq(nil)
          expect(temp_user.reload.created_by_id).to eq(nil)
        end
      end

      context 'destroy_pre_start_email_jobs' do
        let(:nick){ create(:nick, company: company) }
        it 'should enqueue job' do
          nick.destroy
          expect{nick.destroy}.to change(Sidekiq::Queues["default"], :size).by(2)
        end
      end
    end

    context 'after_destroy#callbacks' do
      it { should callback(:anonymise_user_email).after(:destroy) }
      it { should callback(:remove_from_algolia).after(:destroy) }
      it { should callback(:destroy_task_owner_connections).after(:destroy) }
      it { should callback(:run_create_organization_chart_job).after(:destroy) }

      context '#anonymise_user_email' do
        before do
          @email, @personal_email = user.email, user.personal_email
        end

        it 'should anonymise user emails and should create deleted_user_email association after soft deletion' do
          user.destroy!

          expect([user.email, user.personal_email]).to_not eq([@email, @personal_email])
          expect(user.deleted_user_email).not_to be_nil
          expect([user.deleted_user_email.email, user.deleted_user_email.personal_email]).to eq([@email, @personal_email])
        end

        it 'should not anonymise user emails and should not create deleted_user_email association after hard deletion' do
          user.really_destroy!

          expect([user.email, user.personal_email]).to eq([@email, @personal_email])
          expect(user.deleted_user_email).to be_nil
        end
      end

      context 'destroy_task_owner_connections' do
        let(:workstream) {FactoryGirl.create(:workstream, company_id: company.id)}
        let(:task) {FactoryGirl.create(:task, workstream_id: workstream.id, owner_id: sarah.id)}
        let!(:task_user_connection) { create(:task_user_connection, task: task, owner_id: sarah.id) }
        let!(:task_user_connection2) { create(:task_user_connection, user_id: sarah.id, task: task) }

        it 'should destroy all tasks' do
          sarah.reload.destroy
          expect(task.reload.deleted_at).to_not eq(nil)
          expect(task_user_connection.reload.deleted_at).to_not eq(nil)
          expect(task_user_connection2.reload.deleted_at).to_not eq(nil)
        end
      end

      context 'run_create_organization_chart_job' do
        it 'should run_create_organization_chart_job' do
          sarah.company.update(enabled_org_chart: true)
          expect{sarah.destroy}.to change(Sidekiq::Queues["generate_org_chart"], :size).by(1)
        end
      end
    end

    context 'before_save' do
      it { should callback(:nil_if_blank).before(:save) }
      it { should callback(:remove_spacing_in_name).before(:save) }
      it { should callback(:update_preferred_full_name).before(:save) }

      context 'nil_if_blank' do
        it 'should turn blank attribute to nil' do
          sarah.update(preferred_name: '')
          expect(sarah.reload.preferred_name).to eq(nil)
        end

        it 'should not turn value attribute to nil' do
          sarah.update(preferred_name: 'd')
          expect(sarah.reload.preferred_name).to_not eq(nil)
        end
      end

      context 'remove_spacing_in_name' do
        it 'should remove_spacing_in_name' do
          sarah.update(first_name: ' Sarah ', last_name: ' Salem', preferred_name: ' len ')
          expect(sarah.reload.preferred_name).to eq('len')
          expect(sarah.reload.last_name).to eq('Salem')
          expect(sarah.reload.first_name).to eq('Sarah')
        end
      end

      context 'update_preferred_full_name' do
        it 'should update_preferred_full_name' do
          sarah.update(preferred_name: ' len ')
          expect(sarah.reload.preferred_full_name).to eq("len #{sarah.last_name}")
        end
      end
    end

    context 'after_save' do
      it { should callback(:flush_cache).after(:save) }
      it { should callback(:inactive_user_on_departed).after(:save) }
      it { should callback(:assign_manager_role).after(:save) }

      context 'assign_manager_role' do
        it 'should assign_manager_role' do
          sarah.update(manager_id: nick.id)
          expect(nick.reload.user_role.role_type).to eq('manager')
        end

        it 'should not assign_manager_role' do
          sarah.update(manager_id: tim.id)
          expect(nick.reload.user_role.role_type).to_not eq('manager')
        end
      end
    end

    context 'before_create' do
      it { should callback(:initialize_preboarding_progress).before(:create) }
      context 'initialize_preboarding_progress' do
        it 'should initialize_preboarding_progress' do
          expect(sarah.preboarding_progress).to_not eq(nil)
        end
      end
    end

    context 'after_create' do
      it { should callback(:set_calendar_events_settings).after(:create) }
      it { should callback(:update_last_modified_at).after(:create) }
      it { should callback(:create_profile).after(:create) }
      it { should callback(:update_admin_role).after(:create) }
      it { should callback(:set_uid).after(:create) }
      it { should callback(:assign_default_policy).after(:create) }
      it { should callback(:buddy_email).after(:create) }
      it { should callback(:after_create_manager_email).after(:create) }
      it { should callback(:set_guid).after(:create) }
      it { should callback(:track_changed_fields).after(:create) }

      context 'set_calendar_events_settings' do
        it 'should set_calendar_events_settings' do
          expect(sarah.calendar_preferences).to_not eq(nil)
        end
      end

      context 'update_last_modified_at' do
        it 'should update_last_modified_at' do
          expect(sarah.fields_last_modified_at).to_not eq(nil)
        end
      end

      context 'create_profile' do
        it 'should create_profile' do
          expect(sarah.profile).to_not eq(nil)
        end
      end

      context 'update_admin_role' do
        it 'should update_admin_role to admin' do
          user = FactoryGirl.create(:user, company: company, role: 'admin', user_role: nil)
          expect(user.user_role.role_type).to eq('admin')
        end

        it 'should update_admin_role to employee' do
          user = FactoryGirl.create(:user, company: company, role: 'employee', user_role: nil)
          expect(user.user_role.role_type).to eq('employee')
        end

        it 'should update_admin_role to manager' do
          user = FactoryGirl.create(:user, company: company, role: 'employee', user_role: nil, managed_user_ids: [sarah.id])
          expect(user.user_role.role_type).to eq('manager')
        end

        it 'should update_admin_role to super admin' do
          user = FactoryGirl.create(:user, company: company, role: 'account_owner', user_role: nil)
          expect(user.user_role.role_type).to eq('super_admin')
        end

        it 'should update_admin_role to super admin' do
          user = FactoryGirl.create(:user, company: company, expires_in: Time.now, role: 'account_owner', user_role: nil)
          expect(user.user_role).to eq(nil)
        end
      end

      context 'set_uid' do
        it 'should set_uid' do
          expect(sarah.uid).to_not eq(nil)
        end
      end

      context 'assign_default_policy' do
        let!(:pto_policy) {create(:default_pto_policy, company: company)}
        it 'should assign_default_policy' do
          user = FactoryGirl.create(:user, company: company)
          expect(user.assigned_pto_policies.count).to eq(1)
        end

        it 'should not assign_default_policy' do
          company.update(enabled_time_off: false)
          user = FactoryGirl.create(:user, company: company)
          expect(user.assigned_pto_policies.count).to eq(0)
        end
      end

      context 'buddy_email' do
        it 'should send buddy_email' do
          expect{FactoryGirl.create(:user, company: company, buddy: sarah)}.to change(ManagerBuddyEmailJob.jobs, :size).by(1)
        end

        it 'should not send buddy_email' do
          expect{FactoryGirl.create(:user, company: company)}.to change(ManagerBuddyEmailJob.jobs, :size).by(0)
        end
      end

      context 'after_create_manager_email' do
        it 'should send manger email' do
          expect{FactoryGirl.create(:user, company: company, manager: sarah)}.to change(ManagerBuddyEmailJob.jobs, :size).by(1)
        end

        it 'should not send manger email' do
          expect{FactoryGirl.create(:user, company: company, manager: nil)}.to change(ManagerBuddyEmailJob.jobs, :size).by(0)
        end

        it 'should send manger email' do
          expect{FactoryGirl.create(:user, company: company, manager: sarah, current_stage: 'incomplete')}.to change(ManagerBuddyEmailJob.jobs, :size).by(0)
        end
      end

      context 'set_guid' do
        it 'should set_guid' do
          expect(sarah.guid).to_not eq(nil)
        end
      end
    end

    context 'before_update' do
      it { should callback(:update_hellosign_signature_email).before(:update) }

      context 'update_hellosign_signature_email' do
        it 'should update_hellosign_signature_email' do
          expect{sarah.update(email: 'sdf@sdfs.df')}.to change(Sidekiq::Queues["generate_big_reports"], :size).by(1)
          expect{sarah.update(personal_email: 'sdf@sdfs.df')}.to change(Sidekiq::Queues["generate_big_reports"], :size).by(1)
        end

        it 'should not update_hellosign_signature_email' do
          expect{sarah.update(first_name: 'sdf@sdfs.df')}.to change(Sidekiq::Queues["generate_big_reports"], :size).by(0)
        end
      end

      # context 'assign_last_balance_to_policies' do
      #   let!(:nick) {create(:user_with_manager_and_policy, start_date: Time.now - 10.days, company: company)}
      #   it 'should assign_last_balance_to_policies' do
      #     policy = nick.pto_policies.first
      #     assigned_policy = nick.assigned_pto_policies.first
      #     policy.update(accrual_frequency: 1, allocate_accruals_at: 1)
      #     assigned_policy.update(start_of_accrual_period: 3.days.ago, balance_updated_at: 3.days.ago)
      #     assigned_policy.reload
      #     nick.update(termination_date: 1.days.ago)

      #     expect(assigned_policy.balance < assigned_policy.reload.balance).to eq(true)
      #   end
      # end
    end

    context 'after_update' do
      it { should callback(:update_free_admin_role).after(:update) }
      it { should callback(:update_calendar_events).after(:update) }
      it { should callback(:logout_user).after(:update) }
      it { should callback(:update_admin_role).after(:update) }
      it { should callback(:update_user_role).after(:update) }
      it { should callback(:manager_form_completion).after(:update) }
      it { should callback(:notify_account_creator_about_manager_form_completion).after(:update) }
      it { should callback(:notify_user_about_change_in_start_date).after(:update) }
      it { should callback(:buddy_email).after(:update) }
      it { should callback(:fix_counters).after(:update) }
      it { should callback(:update_assigned_policies).after(:update) }
      it { should callback(:flush_location_and_team_cache).after(:update) }
      it { should callback(:remove_information_on_inactive).after(:update) }
      it { should callback(:restore_information_on_active).after(:update) }
      it { should callback(:preboarding_finished).after(:update) }
      it { should callback(:onboarding_finished).after(:update) }
      it { should callback(:update_current_stage_on_start_date_change).after(:update) }
      it { should callback(:update_current_stage_on_termination_date_change).after(:update) }
      it { should callback(:run_update_organization_chart_job).after(:update) }
      it { should callback(:run_create_organization_chart_job).after(:update) }
      it { should callback(:update_termination_snapshot).after(:update) }
      it { should callback(:lock_user).after(:update) }
      it { should callback(:offboard_user).after(:update) }
      it { should callback(:update_anniversary_events).after(:update) }
      it { should callback(:update_first_day_snapshots).after(:update) }
      it { should callback(:cancel_inactive_pto_requests).after(:update) }
      it { should callback(:track_changed_fields).after(:update) }

      before { company.update(enabled_calendar: true)}
      let!(:nick1) {create(:nick, company: company)}
      context 'update_free_admin_role' do

        it 'should update_free_admin_role' do
          manager = nick1.reload.manager
          nick1.update(manager_id: sarah.id)
          expect(manager.reload.user_role.role_type).to eq('employee')
        end

        it 'should not update_free_admin_role' do
          nick1.update(manager_id: sarah.id)
          nick1.manager.update(role: 'account_owner')
          expect(nick1.manager.reload.user_role.role_type).to eq('super_admin')
        end
      end

      context 'update_calendar_events' do

        it 'should create and destroy calendar events' do
          nick1.update(state: 'inactive')
          expect(nick1.calendar_events.count).to eq(0)
          nick1.update(state: 'active')
          expect(nick1.calendar_events.count).to_not eq(0)
        end
      end

      context 'logout_user' do
        it 'should logout_user' do
          nick1.update(state: 'inactive')
          expect(nick1.tokens).to eq({})
        end
      end

      context 'update_admin_role' do
        before {@manager = nick1.reload.manager}
        it 'should update_admin_role to admin' do
          @manager.update(role: 'admin')
          expect(@manager.user_role.role_type).to eq('admin')
        end

        it 'should update_admin_role to manager' do
          @manager.update(role: 'employee')
          expect(@manager.user_role.role_type).to eq('manager')
        end

        it 'should update_admin_role to auper_admin' do
          @manager.update(role: 'account_owner')
          expect(@manager.user_role.role_type).to eq('super_admin')
        end

        it 'should update_admin_role to account_owner' do
          @manager.update(role: 'account_owner', expires_in: Time.now)
          expect(@manager.user_role.role_type).to eq('manager')
        end

        it 'should update_admin_role to employee' do
          nick1.update(role: 'employee')
          expect(nick1.user_role.role_type).to eq('employee')
        end
      end

      context 'logout_user' do
        it 'should logout_user' do
          nick1.update(state: 'inactive')
          expect(nick1.tokens).to eq({})
        end
      end

      context 'update_user_role' do
        before {@manager = nick1.reload.manager}
        it 'should update_user_role to admin' do
          @manager.update(user_role_id: company.user_roles.where(role_type: UserRole.role_types[:admin]).first.id)
          expect(@manager.role).to eq('admin')
        end

        it 'should update_user_role to employee' do
          @manager.update(user_role_id: company.user_roles.where(role_type: UserRole.role_types[:manager]).first.id)
          expect(@manager.role).to eq('employee')
        end

        it 'should update_user_role to employee' do
          @manager.update(user_role_id: company.user_roles.where(role_type: UserRole.role_types[:employee]).first.id)
          expect(@manager.role).to eq('employee')
        end

        it 'should update_user_role to account_owner' do
          @manager.update(user_role_id: company.user_roles.where(role_type: UserRole.role_types[:super_admin]).first.id)
          expect(@manager.role).to eq('account_owner')
        end
      end

      context 'manager_form_completion' do
        it 'should manager_form_completion' do
          sarah.company.custom_fields.first.update(collect_from: 2)
          sarah.update(manager_id: tim.id, account_creator_id: tim.id)
          expect(sarah.is_form_completed_by_manager).to eq('incompleted')
        end
      end

      context 'notify_account_creator_about_manager_form_completion' do
        it 'should notify_account_creator_about_manager_form_completion' do
          sarah.company.update(manager_form_emails: true)
          sarah.company.custom_fields.first.update(collect_from: 2)
          sarah.update(manager_id: tim.id, account_creator_id: tim.id)
          Sidekiq::Testing.inline! do
            expect{sarah.update(is_form_completed_by_manager: 'completed')}.to change{CompanyEmail.all.count}.by(1)
          end
        end

        it 'should not notify_account_creator_about_manager_form_completion' do
          sarah.company.custom_fields.first.update(collect_from: 2)
          sarah.update(manager_id: tim.id, account_creator_id: tim.id)
          expect{sarah.update(is_form_completed_by_manager: 'completed')}.to change{CompanyEmail.all.count}.by(0)
        end
      end

      context 'notify_user_about_change_in_start_date' do
        it 'should notify_user_about_change_in_start_date' do
          sarah.company.update(start_date_change_emails: true)
          sarah.company.email_templates.find_by_email_type('start_date_change').update(email_to: "<p>asdas@asdasd.asad</p>")
          expect{sarah.update(start_date: Date.today)}.to change{CompanyEmail.all.count}.by(1)
        end

        it 'should not notify_user_about_change_in_start_date' do
          sarah.company.email_templates.find_by_email_type('start_date_change').update(email_to: "<p>asdas@asdasd.asad</p>")
          expect{sarah.update(start_date: Date.today)}.to change{CompanyEmail.all.count}.by(0)
        end
      end

      context 'buddy_email' do
        it 'should send buddy_email' do
          Sidekiq::Testing.inline! do
            sarah.company.update(buddy_emails: true)
            expect{sarah.update(buddy_id: nick1.id)}.to change{CompanyEmail.all.count}.by(1)
          end
        end

        it 'should not send buddy_email' do
          Sidekiq::Testing.inline! do
            expect{sarah.update(buddy_id: nick1.id)}.to change{CompanyEmail.all.count}.by(0)
          end
        end
      end

      context 'remove_information_on_inactive' do
        let!(:custom_field) {create(:custom_field, :user_info_and_profile_custom_field, company_id: company.id)}
        let!(:custom_field_value) {create(:custom_field_value, :value_of_personal_info_custom_field, user_id: nick1.id, custom_field_id: custom_field.id, coworker_id: nick1.manager_id)}
        let!(:pending_hire) { create(:pending_hire, personal_email: 'pending_hire@testtest.com', user_id: nick1.manager_id, company: company) }

        it 'should remove_information_on_inactive' do
          manager = nick1.manager
          sarah.update(buddy: manager)
          manager.reload.update(state: 'inactive')
          expect(nick1.reload.manager_id).to eq(nil)
          expect(sarah.reload.buddy_id).to eq(nil)
          expect(custom_field_value.reload.deleted_at).to_not eq(nil)
          expect(pending_hire.reload.state).to eq('inactive')
        end
      end

      context 'restore_information_on_active' do
        let!(:pending_hire) { create(:pending_hire, personal_email: 'pending_hire@testtest.com', user_id: nick1.id, company: company) }

        it 'should restore_information_on_active' do
          nick1.reload.update(state: 'inactive')
          expect(pending_hire.reload.state).to eq('inactive')
          nick1.reload.update(state: 'active')
          expect(pending_hire.reload.state).to eq('active')
        end
      end

      context 'preboarding_finished' do
        before {nick1.update_columns(current_stage: 'preboarding')}
        it 'should send preboarding_finished' do
          Sidekiq::Testing.inline! {expect{nick1.reload.update(current_stage: 'registered')}.to change{CompanyEmail.count}.by(1)}
        end
      end
      
      context 'onboarding_webhook_completed' do
        before {nick1.update_columns(current_stage: 'preboarding')}
        let!(:webhook) { FactoryGirl.create(:webhook, event: 'onboarding', configurable: { stages: ['all'] }, company: company)}
        it 'should send preboarding_finished' do
          expect{nick1.reload.update(current_stage: 'registered')}.to change(Sidekiq::Queues["webhook_activities"], :size).by(1)
        end
      end

      context 'onboarding_finished' do
        before {nick1.update(current_stage: 'incomplete', start_date: 30.days.ago)}
        it 'should send preboarding_finished' do
          nick1.update(current_stage: 'invited', state: 'active')
          expect(nick1.reload.onboarding_completed).to eq(true)
        end
      end

      context 'update_current_stage_on_start_date_change' do
        it 'should update_current_stage_on_start_date_change' do
          nick1.update(current_stage: 'pre_start')
          stage = nick1.current_stage
          nick1.is_current_stage_changed = false
          nick1.update!(start_date: Date.today - 10.day)
          expect(nick1.reload.current_stage).to_not eq(stage)
        end
      end

      context 'update_current_stage_on_termination_date_change' do
        it 'should update_current_stage_on_termination_date_change' do
          nick1.update(start_date: Date.today - 30.days)
          nick1.update(termination_date: Date.today)
          stage = nick1.reload.current_stage
          nick1.update!(termination_date: Date.today + 10.day)
          expect(nick1.reload.current_stage).to_not eq(stage)
        end
      end

      context 'run_create_organization_chart_job' do
        it 'should run_create_organization_chart_job' do
          nick1.company.update(enabled_org_chart: true)
          expect{nick1.update(manager: sarah)}.to change(Sidekiq::Queues["generate_org_chart"], :size).by(1)
        end
      end

      context 'run_update_organization_chart_job' do
        it 'should run_update_organization_chart_job' do
          nick1.company.update(enabled_org_chart: true)
          expect{nick1.update(first_name: 'sarah')}.to change(Sidekiq::Queues["generate_org_chart"], :size).by(1)
        end
      end

      context 'add_employee_to_integrations' do
        # it 'should add_employee_to_integrations namely' do
        #   company.stub(:integration_type) {'namely'}
        #   expect{nick1.update(current_stage: 'registered')}.to change(Sidekiq::Queues["add_employee_to_hr"], :size).by(1)
        # end

        it 'should add_employee_to_integrations adp_wfn_us' do
          company.stub(:integration_types) {['adp_wfn_us']}
          expect{nick1.update(current_stage: 'registered')}.to change(Sidekiq::Queues["add_employee_to_adp"], :size).by(1)
        end

        # it 'should add_employee_to_integrations xero' do
        #   company.stub(:integration_type) {'xero'}
        #   expect{nick1.update(current_stage: 'registered')}.to change(Sidekiq::Queues["add_employee_to_hr"], :size).by(1)
        # end

        it 'should add_employee_to_integrations deputy' do
          FactoryGirl.create(:deputy_integration, company: nick1.company)
          expect{nick1.update(current_stage: 'registered')}.to change(Sidekiq::Queues["manage_deputy_integration"], :size).by(1)
        end
      end

      context 'offboard_user' do
        it 'should offboard_user' do
          nick1.update(termination_date: 3.days.ago)
          expect(nick1.state).to eq('inactive')
          expect(nick1.current_stage).to eq('departed')
          expect(nick1.calendar_events.count).to eq(0)
        end
        it 'should terminate the user in xero' do
          xero.stub(:api_identifier) {'xero'}
          expect{nick1.update(termination_date: 3.days.ago, xero_id: 123)}.to change(Sidekiq::Queues["update_employee_to_hr"], :size).by(1)
        end
        # it 'should terminate the user in namely' do
        #   company.stub(:integration_type) {'namely'}
        #   expect{nick1.update(termination_date: 3.days.ago, namely_id: 123)}.to change(Sidekiq::Queues["receive_employee_from_hr"], :size).by(1)
        # end
        it 'should terminate the user in deputy' do
          FactoryGirl.create(:deputy_integration, company: nick1.company)
          expect{nick1.update(termination_date: 3.days.ago, deputy_id: 123)}.to change(Sidekiq::Queues["manage_deputy_integration"], :size).by(2)
        end
      end

      context 'update_termination_snapshot' do
        let!(:offboarded_user_with_past_snapshot) { create(:offboarded_user, :user_with_terminated_snapshot, company: company) }

        it 'should not update_termination_snapshot if user is rehired' do
          offboarded_user_with_past_snapshot.update(termination_date: 3.days.ago, is_rehired: true)
          expect(offboarded_user_with_past_snapshot.reload.custom_table_user_snapshots.take.effective_date).not_to eq(3.days.ago.to_date)
        end
        it 'should update_termination_snapshot if temrination date is changed' do
          offboarded_user_with_past_snapshot.update(termination_date: 3.days.ago)
          expect(offboarded_user_with_past_snapshot.reload.custom_table_user_snapshots.take.effective_date).to eq(3.days.ago.to_date)
        end

        it 'should update_termination_snapshot if last day worked is changed' do
          offboarded_user_with_past_snapshot.update(last_day_worked: 3.days.ago)
          expect(offboarded_user_with_past_snapshot.reload.custom_table_user_snapshots.take.terminated_data["last_day_worked"]).to eq(3.days.ago.to_date.to_s)
        end
      end
    end

    context 'before_vlidations' do
      it { should callback(:downcase_emails).before(:validation) }
      it { should callback(:update_onboard_email).before(:validation) }
      it { should callback(:reset_current_user_for_test_env).before(:validation) }
      it { should callback(:ensure_manager_form_token).before(:validation) }
      it { should callback(:ensure_request_information_form_token).before(:validation) }

      let!(:nick1) {create(:nick, email: 'nick@TESTING.com', personal_email: 'nick@TESTING.com')}

      context 'downcase_emails' do
        it 'should have downcase email and personal_email'  do
          expect(nick1.reload.email).to eq('nick@testing.com')
          expect(nick1.reload.personal_email).to eq('nick@testing.com')
        end
      end

      context 'update_onboard_email' do
        let!(:nick2) {create(:nick, personal_email: nil)}
        it 'should update_onboard_email'  do
          nick2.update(personal_email: 'fear@gare.com')
          expect(nick2.reload.onboard_email).to eq('both')
        end
      end

      context 'ensure_manager_form_token' do
        it 'should ensure_manager_form_token'  do
          nick1.update(manager_form_token: nil)
          expect(nick1.reload.manager_form_token).to_not eq(nil)
        end
      end

      context 'ensure_request_information_form_token' do
        it 'should ensure_request_information_form_token'  do
          nick1.update(request_information_form_token: nil)
          expect(nick1.reload.request_information_form_token).to_not eq(nil)
        end
      end
    end
  end

  describe 'validations' do
    subject(:nick1) {create(:nick, onboard_email: User.onboard_emails['both'])}
    before { nick1.stub(:update_onboard_email) {true}}
    it { should validate_presence_of(:personal_email) }
    it { should validate_presence_of(:email) }
    it { should validate_length_of(:password).is_at_least(8).is_at_most(128) }
    it { should allow_value('valid_email@email.com').for(:email) }
    it { should_not allow_value('invalid_emailemail.com').for(:email) }
    it { should allow_value('valid_email@email.com').for(:personal_email) }
    it { should_not allow_value('invalid_emailemail.com').for(:personal_email) }
    it { should allow_value('Pass1234as$ad()').for(:password) }
    it { should_not allow_value('sdfcom').for(:password) }

    context 'validate_email' do
      it 'should not allow to create user with same email' do
        user = build(:nick, company: company)
        expect(user.valid?).to eq(false)
      end
    end

    context 'UpdateUserCompanyValidator' do
      let!(:user) {create(:user)}
      it 'should not allow to update with current user of different company' do
        User.stub(:current) { user}
        expect(nick1.update(email: 'sdfsdfs@fdsf.sdsd')).to eq(false)
      end
    end
  end

  describe '#get_location_name' do

    it 'should get cached user location' do
      user = FactoryGirl.create(:user)
      user.location =FactoryGirl.create(:location)
      allow(Location).to receive(:cached_location_serializer).and_return({:id=>1, :name=>"San Francisco", :users_count=>9, :owner_id=>2, :description=>"Deep v freegan vegan jean shorts.", :people_count=>0})
      expect(user.get_location_name).to eql("San Francisco")
    end

  end

  describe '#get_team_name' do

    it 'should get cached user team name ' do
      user = FactoryGirl.create(:user)
      user.team =FactoryGirl.create(:team)
      allow(Team).to receive(:cached_team_serializer).and_return({:id=>1, :name=>"Engineering", :users_count=>6, :owner_id=>2, :description=>"Neutra cardigan tumblr humblebrag.", :people_count=>0})
      expect(user.get_team_name).to eql("Engineering")
    end

  end


  describe '#cached_managed_user_ids' do

    it 'should get cached managed user ids of peter user' do
      user = FactoryGirl.create(:peter)
      expect(user.cached_managed_user_ids).to eql([])
    end

  end

  describe '#get_cached_role_name' do

    it 'should get cached role name of peter user' do
      user = FactoryGirl.create(:peter)
      expect(user.get_cached_role_name).to eql(user.user_role_name)
    end

  end

  describe '#medium_picture' do

    it 'should get user profile medium picture object of peter user' do
      user = FactoryGirl.create(:peter)
      expect(user.medium_picture).to eql(user.profile_image.file.medium.to_s)
    end

  end

  describe '#original_picture' do

    it 'should get user profile original picture object of peter user' do
      user = FactoryGirl.create(:peter)
      expect(user.original_picture).to eql(user.profile_image.file.to_s)
    end

  end


  describe '#get_object_name' do

    it 'should get user full name when called object name ' do
      user = FactoryGirl.create(:peter)
      expect(user.get_object_name).to eql(user.full_name)
    end

  end

  describe '#employee_type' do

    it 'should get user employee_type' do
      user = FactoryGirl.create(:peter)
      expect(user.employee_type).to eql(nil)
    end

  end

  describe '#set_employee_role' do

    it 'should set user role as employe if previous role as account owner' do
      user = FactoryGirl.create(:test1)
      user_role = user.user_role.name
      user.set_employee_role
      expect(user.user_role.name).not_to eql(user_role)
      expect(user.user_role.name).to eql("Employee")
    end

  end


  describe '#get_prefrence_field' do

    before(:each) do
       @user = FactoryGirl.create(:user)
    end

    it 'should get field values for above field termination_type, eligible_for_rehire, first_name, last_name , preferred_name , personal_email' do
      preferred_fields = ["termination_type","eligible_for_rehire","first_name","last_name","preferred_name","personal_email"]
      preferred_fields.each do |field|
       expect(@user.send(:get_prefrence_field,field.to_s)).to eql(@user.send(field.to_sym))
      end
    end

    it 'should get field value for above user profile fields linkedin, twitter, github' do
      preferred_fields = ["linkedin","twitter","github"]
      preferred_fields.each do |field|
       expect(@user.send(:get_prefrence_field,field.to_s)).to eql(@user.profile.send(field.to_sym))
      end
    end

    it 'should get prefrence field value for company email' do
      expect(@user.send(:get_prefrence_field,"company_email")).to eql(@user.email)
    end

    it 'should get prefrence field value for department' do
      expect(@user.send(:get_prefrence_field,"department")).to eql(@user.get_team_name)
    end

    it 'should get prefrence field value for job_title' do
      expect(@user.send(:get_prefrence_field,"job_title")).to eql(@user.title)
    end

    it 'should get prefrence field value for location' do
      expect(@user.send(:get_prefrence_field,"location")).to eql(@user.get_location_name)
    end

    it 'should get prefrence field value for user_id' do
      expect(@user.send(:get_prefrence_field,"user_id")).to eql(@user.id)
    end

    it 'should get prefrence field value for stage' do
      expect(@user.send(:get_prefrence_field,"stage")).to eql(@user.current_stage)
    end

    it 'should get prefrence field value for status' do
      expect(@user.send(:get_prefrence_field,"status")).to eql(@user.state)
    end

    it 'should get prefrence field value for about_you' do
      expect(@user.send(:get_prefrence_field,"about_you")).to eql(@user.get_cached_about_you)
    end

    it 'should get prefrence field value for manager_email' do
      expect(@user.send(:get_prefrence_field,"manager_email")).to eql("")
    end

    it 'should get prefrence field value for access_permission' do
      expect(@user.send(:get_prefrence_field,"access_permission")).to eql(@user.user_role.role_type)
    end

    it 'should get prefrence field value for start_date' do
      expect(@user.send(:get_prefrence_field,"start_date")).to eql(@user.start_date.strftime("%m/%d/%Y"))
    end

    it 'should get prefrence field value for last_date_worked' do
      expect(@user.send(:get_prefrence_field,"last_date_worked")).to eql(nil)
    end

    it 'should get prefrence field value for last_active' do
      expect(@user.send(:get_prefrence_field,"last_active")).to eql("")
    end

    it 'should get prefrence field value for job_tier' do
      expect(@user.send(:get_prefrence_field,"job_tier")).to eql("")
    end

    it 'should get prefrence field value for buddy' do
      expect(@user.send(:get_prefrence_field,"buddy")).to eql("")
    end

    it 'should get prefrence field value for employment_status' do
      expect(@user.send(:get_prefrence_field,"employment_type")).to eql(nil)
    end

    it 'should get prefrence field value for termination_type' do
      expect(@user.send(:get_prefrence_field,"termination_type")).to eql(nil)
    end

    it 'should get prefrence field value for termination_date' do
      expect(@user.send(:get_prefrence_field,"termination_date")).to eql("")
    end

    it 'should get prefrence field value for manager' do
      expect(@user.send(:get_prefrence_field,"manager")).to eql("")
    end

  end

  describe '#remove_role' do

    it 'should update role as employee if not user not Ghost Admin and not a manager' do
      user = FactoryGirl.create(:peter)
      expect(user.user_role.name).to eql("Admin")
      user.remove_role
      expect(user.user_role.name).to eql("Employee")
    end

    # it 'should destroy self if user role is Ghost Admin' do
    #   user = FactoryGirl.create(:test1)
    #   user.user_role = FactoryGirl.create(:ghost_admin)
    #   allow(user).to receive(:destroy).and_return(true)
    #   user.remove_role
    #   expect(user.id).should(nil)
    # end
  end

  describe '#employee?' do
    it 'returns true if user is an employee' do
      expect(FactoryGirl.create(:nick).employee?).to be_truthy
      expect(FactoryGirl.create(:tim).employee?).to be_truthy
    end

    it 'returns false if user is not employee' do
      expect(FactoryGirl.create(:peter).employee?).to be_falsy
      expect(FactoryGirl.create(:sarah).employee?).to be_falsy
    end
  end

  describe '#full_name' do
    it 'returns user first_name and last_name' do
      expect(subject.full_name).to eq("#{subject.first_name} #{subject.last_name}")
    end
  end

  describe '#state_transition' do
    it 'user can be actived and deactived' do
      expect(subject.state).to eq("active")
      subject.deactivate
      expect(subject.state).to eq("inactive")

      subject.activate
      expect(subject.state).to eq("active")
    end
  end

  describe '#stage_transition' do
    it 'user stage cannot transition to pre_start without preboarding completion' do
      expect(subject.current_stage).to eq("preboarding")
      subject.start_date = Date.today + 2.days
      subject.onboarding
      expect(subject.current_stage).to eq("preboarding")
    end
  end

  describe '#stage_transition' do
    before(:each) do
      subject.update(current_stage: "pre_start")
      expect(subject.current_stage).to eq("pre_start")
    end

    it 'user stage transition to pre_start' do
      subject.start_date = Date.today + 2.days
      subject.onboarding
      expect(subject.current_stage).to eq("pre_start")
    end

    it 'user stage transition to first_week' do
      subject.start_date = 2.days.ago
      subject.onboarding
      expect(subject.current_stage).to eq("first_week")
    end

    it 'user stage transition to first_month' do
      subject.start_date = 12.days.ago
      subject.onboarding
      expect(subject.current_stage).to eq("first_month")
    end

    it 'user stage transition to ramping_up' do
      subject.start_date = 42.days.ago
      subject.onboarding
      expect(subject.current_stage).to eq("ramping_up")
    end
  end

  describe '#stage_transition' do
    it 'user cannot transition to registered from preboarding' do
      subject.task_user_connections.first.update_column :state, 'completed'
      expect(subject.current_stage).not_to eq("registered")
    end
  end

  describe '#stage_transition' do
    it 'user can transition to last_week' do
      subject.termination_date = Date.today + 2.days
      subject.offboarding
      expect(subject.current_stage).to eq("last_week")
    end
  end

  describe '#stage_transition' do
    it 'user can transition to last_month' do
      subject.termination_date = Date.today + 12.days
      subject.offboarding
      expect(subject.current_stage).to eq("last_month")
    end
  end

  describe '#stage_transition' do
    it 'user can transition to offboarding' do
      subject.termination_date = Date.today + 32.days
      subject.offboarding
      expect(subject.current_stage).to eq("offboarding")
    end
  end

  describe '#stage_transition' do
    it 'user can transition to departed' do
      subject.termination_date = 2.days.ago
      subject.offboarded
      expect(subject.current_stage).to eq("departed")
    end
  end

  describe '#offboarding_initiated?' do
    it 'should create offboarding calendar event for user' do
      invited_user.update(termination_date:  Date.today + 4.days, current_stage: 'last_week', last_day_worked: Date.today + 3.days)
      last_date_event = invited_user.calendar_events.where(event_type: CalendarEvent.event_types[:last_day_worked]).take
      expect(last_date_event.event_start_date).to eq(Date.today + 3.days)
    end
  end

  describe '#update_anniversary_events' do
    it 'should change the calendar anniversary events and start date event' do
      start_date = invited_user.start_date
      first_anniversary = invited_user.calendar_events.where(event_type: CalendarEvent.event_types[:anniversary]).order(event_start_date: :asc).first
      expect(first_anniversary.event_start_date).to eq(start_date + 6.months)

      start_date_event = invited_user.calendar_events.where(event_type: CalendarEvent.event_types[:start_date]).take
      expect(start_date_event.event_start_date).to eq(start_date)

      invited_user.update(start_date: start_date + 2.days)

      start_date = start_date + 2.days
      first_anniversary = invited_user.calendar_events.where(event_type: CalendarEvent.event_types[:anniversary]).order(event_start_date: :asc).first
      expect(first_anniversary.event_start_date).to eq(start_date + 6.months)

      start_date_event = invited_user.calendar_events.where(event_type: CalendarEvent.event_types[:start_date]).take
      expect(start_date_event.event_start_date).to eq(start_date)
    end
  end

  describe '#create birthday event' do
    it 'should create default 6 birthday events on calendar' do
      dob_custom_field = subject.company.custom_fields.where(name: 'Date of Birth').take
      bday = Date.today - 20.years
      subject.custom_field_values.create(custom_field_id: dob_custom_field.id, value_text: bday.to_s)

      birthday_events = subject.calendar_events.where(event_type: CalendarEvent.event_types[:birthday])
      expect(birthday_events.count).to eq(6)
      expect(birthday_events.last.event_start_date.day).to eq(bday.day)
    end
  end

  describe 'after auditable fields are updated' do
    it 'creates history for those fields' do
      user = build(:user, :run_field_history_callback, company_id: company.id)
      User.current = create(:user, company_id: company.id)
      expect{ user.save }.to change{ user.field_histories.count }.by(10)
    end
  end

  describe '#preboarding_finished' do
    it 'should finish preboarding for user' do
      nick.update(current_stage: 'pre_start')
      expect(nick.current_stage).to eq('pre_start')
    end
  end

  describe '#offboarding_user' do
    it 'should start user\'s last week' do
      tim.update!(termination_date: DateTime.now)
      expect(tim.termination_date).to eq((DateTime.now.strftime('%a, %d %b %Y')).to_date)
      tim.offboarding!
      expect(tim.current_stage).to eq('last_week')
    end
  end

  describe '#full_name' do
    it 'returns user first_name and last_name' do
      expect(subject.full_name).to eq("#{subject.first_name} #{subject.last_name}")
    end
  end

  describe 'user can have same personal email in different companies'  do
    it 'should not raise Invalid record error' do
      company2 = FactoryGirl.create(:company, notifications_enabled: true, preboarding_complete_emails: true)
      FactoryGirl.create(:user, company: company, personal_email: "duplicate@test.com")
      expect { FactoryGirl.create(:user, company: company2, personal_email: "duplicate@test.com") }.not_to raise_error
    end
  end

  describe 'user should not be saved with duplicate personal email'  do
    it 'should raise Invalid record error' do
      FactoryGirl.create(:user, company: company, personal_email: "duplicate@test.com")
      expect { FactoryGirl.create(:user, company: company, personal_email: "duplicate@test.com") }.to raise_error(ActiveRecord::RecordInvalid , /Email addresses must be unique, please try again/)
    end
  end

  describe 'user should not be saved with duplicate email'  do
    it 'should raise Invalid record error' do
      FactoryGirl.create(:user, email: "duplicate@test.com")
      expect { FactoryGirl.create(:user, email: "duplicate@test.com") }.to raise_error(ActiveRecord::RecordInvalid , /Email addresses must be unique, please try again/)
    end
  end

  describe '#restore' do
    context 'deleted user with multiple deleted assigned_pto_polices' do
      let!(:user_with_deleted_policies){ create(:user_with_deleted_policies) }
      before(:each) do
        user_with_deleted_policies.update_column(:deleted_at, Time.now)
        create(:deleted_user_email, user: user_with_deleted_policies, email: user_with_deleted_policies.email, personal_email: user_with_deleted_policies.personal_email)
      end

      it 'restores one out of multiple soft deleted assigned_pto_policies belonging to same pto_policy' do
        user_with_deleted_policies.restore(recursive: true)
        expect(user_with_deleted_policies.assigned_pto_policies.size).to eq(1)
      end

      it 'restores the latest assigned_pto_policy out of multiple soft deleted assigned_pto_policies belonging to same pto_policy' do
        id = user_with_deleted_policies.assigned_pto_policies.with_deleted.last.id
        user_with_deleted_policies.restore(recursive: true)
        expect(user_with_deleted_policies.assigned_pto_policies.first.id).to eq(id)
      end
    end

    context 'deleted user with deleted assigned_pto_policies having deleted pto_policy' do
      let!(:user_with_deleted_policies){ create(:assigned_policy_having_no_pto_policy) }
      before(:each) do
        user_with_deleted_policies.update_column(:deleted_at, Time.now)
        create(:deleted_user_email, user: user_with_deleted_policies, email: user_with_deleted_policies.email, personal_email: user_with_deleted_policies.personal_email)
      end

      it 'should not restore assigned_pto_policies' do
        user_with_deleted_policies.restore(recursive: true)
        expect(user_with_deleted_policies.assigned_pto_policies.size).to eq(0)
      end
    end


    context 'deleted user with deleted assigned_pto_policies not matching latest pto_policys filters' do
      let!(:user_with_deleted_policies){ create(:user_with_deleted_assigned_pto_policy) }
      before(:each) do
        user_with_deleted_policies.update_column(:deleted_at, Time.now)
        create(:deleted_user_email, user: user_with_deleted_policies, email: user_with_deleted_policies.email, personal_email: user_with_deleted_policies.personal_email)
      end

      it 'should not restore assigned_pto_polices' do
        policy = user_with_deleted_policies.assigned_pto_policies.with_deleted.first.pto_policy
        policy.update_column(:filter_policy_by, {"teams": [user_with_deleted_policies.team_id + 1], "location": [user_with_deleted_policies.location_id + 1], "employee_status": ["all"]})
        user_with_deleted_policies.restore(recursive: true)
        expect(user_with_deleted_policies.assigned_pto_policies.size).to eq(0)
      end
    end
  end

  describe 'after_update#cancel_inactive_pto_requests' do
    let(:user){ create(:user_with_manager_and_policy, company: company) }
    before {User.current = user}
    let!(:pto_request) { create(:pto_request, user: user, pto_policy: user.pto_policies.first, partial_day_included: false, status: 0, begin_date: 10.days.from_now.to_date, end_date: 12.days.from_now.to_date, balance_hours: 24) }
    context 'user has pto request and current_stage is being set to departed' do
      it 'should cancel pto requests' do
        user.current_stage = "departed"
        user.save
        expect(user.reload.pto_requests.first.status).to eq('cancelled')
      end
    end

    context 'user has pto request and state is being set to active' do
      before do
        user.update_column(:state, 'inactive')
        user.state = 'active'
        user.save
      end

      it 'should not change pto request status' do
        expect(user.pto_requests.first.status).to eq('pending')
      end
    end

    context 'user has pto request and current stage is being set to registered' do
      it 'should not change pto request status' do
        user.current_stage = 'registered'
        user.save
        expect(user.pto_requests.first.status).to eq('pending')
      end
    end

    context 'user has pto_request of denied state' do
      before do
        pto_request.update_column(:status, 2)
      end
      it 'should not change pto request status' do
        user.current_stage = 'departed'
        user.save
        expect(user.pto_requests.first.status).to eq('denied')
      end
    end

    context 'user has pto request approved' do
      before do
        pto_request.update_column(:status, 1)
      end
      it 'should change pto request to cancelled' do
        user.current_stage = 'departed'
        user.save
        expect(user.pto_requests.first.status).to eq('cancelled')
      end
    end

    context 'user has pto request approved and of past' do
      before do
        pto_request.update_columns(status: 1, begin_date: Date.today - 1.days, end_date: Date.today - 1.days)
      end
      it 'should not change status of pto request' do
        user.current_stage = 'departed'
        user.save
        expect(user.pto_requests.first.status).to eq('approved')
      end
    end
  end

  describe 'before_restore#restore_user_email' do
    context 'user previous email should be restored before restoring deleted user' do
      before do
        @email, @personal_email = user.email, user.personal_email
        user.destroy
      end

      it 'should delete deleted_user_email association, and restore emails on restoring user' do
        user.restore
        user.reload

        expect(user.deleted_user_email).to be_nil
        expect([user.email, user.personal_email]).to eq([@email, @personal_email])
      end
    end
  end

  describe 'update_assigned_policies' do
    let!(:peter) { create(:peter, :with_location_and_team, company: company)  }
    before do
      @cf = peter.company.custom_fields.where(field_type: CustomField.field_types[:employment_status]).first
      @cfv = CustomFieldValue.create(custom_field: @cf, user: peter, custom_field_option_id: @cf.custom_field_options.first.id)
      Sidekiq::Testing.inline! do
        @pto_policy = FactoryGirl.create(:default_pto_policy, for_all_employees: false, filter_policy_by: {"teams": [peter.team_id], "location": [peter.location_id], "employee_status": [@cf.custom_field_options.first.id]}, company: company, is_enabled: false)
        @pto_policy.update(is_enabled: true)
      end
    end

    context 'it should reload old policy if present' do
      it 'should reload old assigned policy on location change' do
        old_assigned_policy_id = peter.assigned_pto_policies.first.id
        old_location_id = peter.location_id
        peter.update!(location_id: nil)

        expect(peter.reload.assigned_pto_policies.count).to eq(0)

        peter.update!(location_id: old_location_id)

        expect(peter.assigned_pto_policies.first.id).to eq(old_assigned_policy_id)
      end

      it 'should reload old assigned policy on team change' do
        old_assigned_policy_id = peter.assigned_pto_policies.first.id
        old_team_id = peter.team_id

        peter.update!(team_id: nil)

        expect(peter.reload.assigned_pto_policies.count).to eq(0)

        peter.update!(team_id: old_team_id)

        expect(peter.assigned_pto_policies.first.id).to eq(old_assigned_policy_id)
      end

      it 'should reload old assigned policy on status change' do
        old_assigned_policy_id = peter.assigned_pto_policies.first.id

        @cfv.update!(custom_field_option_id: @cf.custom_field_options.second.id)

        expect(peter.reload.assigned_pto_policies.count).to eq(0)

        @cfv.update!(custom_field_option_id: @cf.custom_field_options.first.id)

        expect(peter.assigned_pto_policies.first.id).to eq(old_assigned_policy_id)
      end

      it 'should create new assigned_pto_policy if no assigned_pto_policy is present with deleted' do
        old_assigned_policy_id = peter.assigned_pto_policies.first.id
        old_team_id = peter.team_id
        peter.update!(team_id: nil)

        expect(peter.reload.assigned_pto_policies.count).to eq(0)
        AssignedPtoPolicy.with_deleted.find(old_assigned_policy_id).really_destroy!
        peter.update!(team_id: old_team_id)

        expect(peter.assigned_pto_policies.first.id).to_not eq(old_assigned_policy_id)
      end
    end
  end

  describe 'method#allowed_to_restore' do
    context 'should check validity of deleted_user_email association' do
      before do
        @email, @personal_email = user.email, user.personal_email

        user.destroy!
      end

      it 'should return true if there is no user with same set of emails' do
        expect(user.allowed_to_restore?).to be_truthy
      end

      it 'should return false if there is user with same set of emails' do
        create(:user, email: @email, personal_email: @personal_email)
        expect(user.allowed_to_restore?).to be_falsy
      end
    end
  end

  describe 'ADP integration callbacks' do
    context 'should not make create adp call' do
      subject(:new_hire) { create(:user, company: company) }
      subject(:integration) { create(:adp_integration, company: company, api_name: :adp_wfn_us) }

      it 'should not create if integration is not present on current stage change' do
        expect{
          new_hire.update(current_stage: User.current_stages[:pre_start])
        }.to change(Sidekiq::Queues["add_employee_to_adp"], :size).by(0)
      end

      it 'should not create if integration is present also adp-us id on current stage change' do

        new_hire.update_column(:adp_wfn_us_id, 123)
        integration

        expect{
          new_hire.update(current_stage: User.current_stages[:pre_start])
        }.to change(Sidekiq::Queues["add_employee_to_adp"], :size).by(0)
      end

      it 'should not create if integration is present also adp-can id on current stage change' do

        new_hire.update_column(:adp_wfn_can_id, 123)
        integration

        expect{
          new_hire.update(current_stage: User.current_stages[:pre_start])
        }.to change(Sidekiq::Queues["add_employee_to_adp"], :size).by(0)
      end
    end

    context 'should make create adp call' do
      subject(:new_hire) { create(:user, company: company) }
      subject(:integration_adp_us) { create(:adp_wfn_us_integration, company: company) }
      subject(:integration_adp_can) { create(:adp_wfn_can_integration, company: company) }

      it 'should create if adp-us integration is present on current stage change' do

        integration_adp_us

        expect{
          new_hire.update(current_stage: User.current_stages[:pre_start])
        }.to change(Sidekiq::Queues["add_employee_to_adp"], :size).by(1)
      end

      it 'should create if adp-us integration is present on current stage change' do

        integration_adp_us

        expect{
          new_hire.update(current_stage: User.current_stages[:pre_start])
        }.to change(Sidekiq::Queues["add_employee_to_adp"], :size).by(1)
      end
    end
  end

  describe 'validate onboarding and offboarding emails' do
    let(:location) { create(:location, company: company) }
    subject(:peter) {FactoryGirl.create(:peter, current_stage: :incomplete, role: "employee", title: "Software Engineer", location: location, company: company)}
    let!(:email_template) {create(:email_template, company: peter.company, meta: {location_id: location.id})}
    let!(:email_template_dup) {create(:email_template, company: peter.company, name: "another invite")}
    let!(:email_template_all_types) {create(:email_template, company: peter.company, name: "all types invite")}

    it 'returns default onboarding email templates dependent of user location' do
      peter.smart_assignment = true
      peter.schedule_default_onboarding_emails(peter.id)
      expect(peter.user_emails.count).to be(2)
    end

    it 'returns offboard email template dependent of user location' do
      email_template.update(email_type: :offboarding, meta: {team_id: ["all"], location_id: [peter.location_id], employee_type: ["all"]})
      email_template_dup.update(email_type: :offboarding)
      email_template_all_types.update(email_type: :offboarding)
      peter.assign_default_offboarding_emails({last_day_worked: "#{10.days.from_now}", termination_date: "#{10.days.from_now}", location_id: peter.location_id}, peter.id)
      expect(peter.user_emails.count).to be(3)
    end

    it 'returns offboard  email template for all locations' do
      email_template_all_types.update(email_type: :offboarding)
      email_template_dup.update(email_type: :offboarding)
      peter.assign_default_offboarding_emails({last_day_worked: "#{10.days.from_now}", termination_date: "#{10.days.from_now}"}, peter.id)

      expect(peter.user_emails.count).to be(2)
    end

    it 'returns no email template if user company has no email template with offboarding type' do
      peter.assign_default_offboarding_emails({last_day_worked: "#{10.days.from_now}", termination_date: "#{10.days.from_now}"}, peter.id)
      expect(peter.user_emails.count).to be(0)
    end
  end

  context 'get_reassign_manager_activities_count' do
    let!(:manager) { create(:user, company: company, role: User.roles[:employee])}
    let!(:user) { create(:user, state: :active, current_stage: :registered, company: company, manager:manager) }
    let!(:task){ create(:task, task_type: Task.task_types[:manager])}
    let!(:task_user_connection){ create(:task_user_connection, task: task, user: user, state: 'in_progress', owner_id: manager.id)}

    it 'should get_manager_reassign_tasks count if user, manager and task type is present' do
      user_pending_tasks = User.manager_reassign_tasks(user.id, manager.id, task.task_type)
      expect(user_pending_tasks.count).to eq(1)
    end

    it 'should not get_manager_reassign_tasks count if user is not present' do
      user_pending_tasks = User.manager_reassign_tasks(nil, manager.id, task.task_type)
      expect(user_pending_tasks&.count).to eq(nil)
    end

    it 'should not get_manager_reassign_tasks count if manager is not present' do
      user_pending_tasks = User.manager_reassign_tasks(user.id, nil, task.task_type)
      expect(user_pending_tasks&.count).to eq(nil)
    end

    it 'should not get_manager_reassign_tasks count if task type is not present' do
      user_pending_tasks = User.manager_reassign_tasks(user.id, manager.id, nil)
      expect(user_pending_tasks&.count).to eq(nil)
    end
  end
end
