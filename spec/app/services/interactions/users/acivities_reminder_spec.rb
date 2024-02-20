require 'rails_helper'

RSpec.describe Interactions::Users::ActivitiesReminder do
  describe 'activities reminder' do
    let!(:company) {create(:company, time_zone: "UTC", subdomain: "task_activities_sub")}
    let!(:user) {create(:user, start_date: Date.today - 10.days, company: company, current_stage: :registered)}

    before do
      time = Time.now.utc().beginning_of_week.change(hour: 8)
      Time.stub(:now) {time}
      DateTime.stub(:now) {time}
      Date.stub(:today) {time.to_date}
    end

    context 'manage_overdue_individual_task_emails' do
      let!(:task) {create(:task, task_type: :owner, owner: user)}
      let!(:task_user_connection) {create(:task_user_connection, due_date: Date.today - 10.days, user: user, task: task, owner: user)}

      it 'should schedule email' do
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(1)
      end

      it 'should  not schedule email for future due date' do
        task_user_connection.update(due_date: Date.today + 10.days)
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(0)
      end

      it 'should  not schedule email if task type is jira' do
        task.update(task_type: :jira)
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(0)
      end

      it 'should  not schedule email if task is not in progress' do
        task_user_connection.complete!
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(0)
      end

      it 'should  not schedule email if user stage is incomplete' do
        user.update(current_stage: :incomplete)
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(0)
      end

      it 'should  not schedule email if user is inactive' do
        user.update(state: :inactive)
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(0)
      end

      it 'should  not schedule email if owner type is workspace' do
        task_user_connection.update(owner_type: :workspace)
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(0)
      end

    end

    context 'manage_overdue_individual_task_emails' do
      let!(:workspace) {create(:workspace, company: company, associated_email: "tooslow@slow.com")}
      let!(:task) {create(:task, task_type: :workspace, workspace: workspace)}
      let!(:task_user_connection) {create(:task_user_connection, due_date: Date.today - 10.days, user: user, task: task, owner_type: :workspace, workspace: workspace)}

      it 'should schedule email' do
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(1)
      end

      it 'should  not schedule email for future due date' do
        task_user_connection.update(due_date: Date.today + 10.days)
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(0)
      end

      it 'should  not schedule email if task type is jira' do
        task.update(task_type: :jira)
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(0)
      end

      it 'should  not schedule email if task is not in progress' do
        task_user_connection.complete!
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(0)
      end

      it 'should  not schedule email if owner type is individual' do
        task_user_connection.update(owner_type: :individual)
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by_at_least(0)
      end

      it 'should  not schedule email if associated email is not present' do
        workspace.update(associated_email: nil)
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(0)
      end
    end

    context 'manage_ovedue_document_emails paperwork_request' do
      let!(:paperwork_request) { create(:paperwork_request, :request_skips_validate, state: 'assigned', user: user, due_date: Date.today-1.day) }

      it 'should schedule email' do
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(1)
      end

      it 'should  not schedule email if state is signed' do
        paperwork_request.update(state: "signed")
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(0)
      end

      it 'should  not schedule email if state is all signed' do
        paperwork_request.update(state: "all_signed")
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(0)
      end


      it 'should  not schedule email if user is inactive' do
        user.update(state: :inactive)
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(0)
      end

      it 'should  not schedule email if user stage is incomplete' do
        user.update(current_stage: :incomplete)
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(0)
      end
    end

    context 'manage_ovedue_document_emails user_document_connection' do
      let!(:document) {create(:document, company: company)}
      let(:document_connection_relation) { create(:document_connection_relation) }
      let!(:user_document_connection) {create(:user_document_connection, state: 'request', user: user, document_connection_relation: document_connection_relation, due_date: Date.today-1.day)}

      it 'should schedule email' do
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(1)
      end

      it 'should  not schedule email if state is complete' do
        user_document_connection.update_column(:state, "comlpeted")
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(0)
      end

      it 'should  not schedule email if user is inactive' do
        user.update(state: :inactive)
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(0)
      end

      it 'should  not schedule email if user stage is incomplete' do
        user.update(current_stage: :incomplete)
        expect {Interactions::Users::ActivitiesReminder.new.perform}.to change(Sidekiq::Extensions::DelayedMailer.jobs, :size).by(0)
      end
    end
  end
  
end
