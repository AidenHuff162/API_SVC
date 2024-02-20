require 'rails_helper'

RSpec.describe SlackIntegrationJob, type: :job do

	let(:company) { create(:company) }
	let(:user) { create(:user, company: company, slack_notification: true) }
  let!(:slack_integration) { create(:slack_integration, company: company) }
  let(:workstream) {FactoryGirl.create(:workstream, company_id: company.id)}
  let(:in_progress_task) {FactoryGirl.create(:task, workstream_id: workstream.id, owner_id: user.id)}
  let(:completed_task) {FactoryGirl.create(:task, workstream_id: workstream.id, owner_id: user.id)}
  let!(:in_progress_task_user_connection) {create(:task_user_connection, due_date: Time.now, user: user, task: in_progress_task, owner: user, state: 'in_progress')}
  let!(:completed_task_user_connection) {create(:task_user_connection, due_date: Time.now, user: user, task: completed_task, owner: user, state: 'completed')}


	context 'Slack Authentication' do
    before do
      allow_any_instance_of(SlackService::SlackWorkspaceAuthenticate).to receive(:authenticate?).and_return(true)
    end
    context 'shall not authenticate slack' do
      it "shall not Authenticate slack notification if company id is not present" do
        response = SlackIntegrationJob.new.perform('Slack_Auth', state: {"company_id" => nil, "user_id" => user.id}, payload: {"code" => "code"})
        expect(response).not_to eq(true)
      end

      it "shall not Authenticate slack notification if user id is not present" do
        response = SlackIntegrationJob.new.perform('Slack_Auth', state: {"company_id" => company.id, "user_id" => nil}, payload: {"code" => "code"})
        expect(response).not_to eq(true)
      end
    end

    context 'authenticate slack' do
      it "should return true response" do
        response = SlackIntegrationJob.new.perform('Slack_Auth', state: {"company_id" => company.id, "user_id" => user.id}, payload: {"code" => "code"})
        expect(response).to eq(true)
    	end
    end
  end

  context 'Slack Respond' do
    before do
      allow_any_instance_of(SlackService::PushSlackInteractiveMessage).to receive(:process_response?).and_return(true)
    end
    context 'slack shall not respond' do
      it 'slack shall not respond if current company is not present' do
        response = SlackIntegrationJob.new.perform('Slack_Respond', payload: {"payload" => nil})
        expect(response).not_to eq(true)
      end

      it 'slack shall not respond if time stamp is not present' do
        allow_any_instance_of(SlackService::PushSlackInteractiveMessage).to receive(:find_current_company).and_return(company)
        response = SlackIntegrationJob.new.perform('Slack_Respond', payload: {"payload" => nil})

        expect(response).not_to eq(true)
      end
    end

    context 'Slack shall Respond' do
      it "Should return true" do
        allow_any_instance_of(SlackService::PushSlackInteractiveMessage).to receive(:find_current_company).and_return(company)
        allow_any_instance_of(SlackService::PushSlackInteractiveMessage).to receive(:find_message_time_stamp).and_return(true)

        response = SlackIntegrationJob.new.perform('Slack_Respond', payload: {"payload" => nil})
        expect(response).to eq(true)
      end
    end
  end

  context 'Slack Help' do
    context 'Slack shall generate help' do
      it "Should return true" do
        allow(RestClient).to receive(:post).and_return(true)

        response = SlackIntegrationJob.new.perform('Slack_Help', payload: {"response_url" => nil})
        expect(response).to eq(true)
      end
    end
  end

  context 'Task Assign' do
    before do
      allow_any_instance_of(SlackService::BuildMessage).to receive(:prepare_attachments).and_return(true)
      allow(Integrations::SlackNotification::Push).to receive(:push_notification).and_return(true)
      @content = {tasks: [{id: in_progress_task.id}]}
    end

    context 'Slack shall not send task assign message' do
      it "shall not return true if company id is not present" do
        response = SlackIntegrationJob.new.perform('Task_Assign', current_company_id: nil, user_id: user.id, message_content: @content)
        expect(response).not_to eq(true)
      end

      it "shall not return true if company id is not present" do
        response = SlackIntegrationJob.new.perform('Task_Assign', current_company_id: company.id, user_id: nil, message_content: @content)
        expect(response).not_to eq(true)
      end
       
       it "shall not return true if integration is not present" do
        slack_integration.destroy!
        response = SlackIntegrationJob.new.perform('Task_Assign', current_company_id: company.id, user_id: user.id, message_content: @content)
        expect(response).not_to eq(true)
      end

      it "shall not return true if task is already complete" do
        slack_integration.destroy!
        complete_task = {tasks: [{id: completed_task.id}]}
        response = SlackIntegrationJob.new.perform('Task_Assign', current_company_id: company.id, user_id: user.id, message_content: complete_task)
        expect(response).not_to eq(true)
      end
    end

    context 'Slack shall send task assign message' do
      it "shall return true" do
        response = SlackIntegrationJob.new.perform('Task_Assign', current_company_id: company.id, user_id: user.id, message_content: @content)
        expect(response).to eq(true)
      end
    end
  end

  it "Disable slack notification for the users" do
    user.update(slack_notification: true)
    response = SlackIntegrationJob.new.perform('Disable_Users_Slack_Notification',{current_company_id: company.id})
    expect(company.users.find(user.id).slack_notification).to eq(false)
  end
end
