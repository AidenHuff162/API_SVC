require 'rails_helper'

RSpec.describe Productivity::ServiceNow do
  describe 'Productivity::ServiceNow Service' do
    let(:company) { create(:company) }
    let(:service_now_instance) { create(:service_now_instance, company: company) }
    let(:user) { create(:user, company: company) }
    let(:workstream) { create(:workstream, company_id: company.id) }
    let(:task) { create(:task, task_type: 'service_now', workstream_id: workstream.id, owner_id: user.id) }
    let(:task_user_connection) { create(:task_user_connection, task: task, user: user) }
    let(:tuc) { create(:task_user_connection, task: task, user: user, service_now_id: '123') }
    let(:tucs_service_now){ ['234', '567'].map{ |s_id| create(:task_user_connection, task: task, user: user, service_now_id: s_id)} }
    let(:url){'http://test.domain/api/now/table/sc_task'}
    let(:url_with_service_now_id){"#{url}/#{tuc.service_now_id}"}
    let(:completed_tasks_response_body){ %Q({"result": [{"sys_id": "234"}, {"sys_id": "567"}]}) }
    let(:last_log_in_company){ company.loggings.where(integration_name: 'ServiceNow').last }

    let(:created_task_description){
      temp_des = ReverseMarkdown.convert(ReplaceTokensService.new.replace_tokens(task_user_connection.task.description, task_user_connection.user, nil, nil, nil, true, nil, false).gsub(/<img.*?>/, "").gsub(/<iframe.*?iframe>/, ""), unknown_tags: :bypass) rescue ""
      temp_des.gsub(/(\\)([><])/, '\2')
    }
    let(:updated_task_description){
      temp_des = ReverseMarkdown.convert(ReplaceTokensService.new.replace_tokens(tuc.task.description, tuc.user, nil, nil, nil, true, nil, false).gsub(/<img.*?>/, "").gsub(/<iframe.*?iframe>/, ""), unknown_tags: :bypass) rescue ""
      temp_des.gsub(/(\\)([><])/, '\2')
    }
    let(:created_task_body){
      JSON.generate({
        'short_description' => "#{task.name} for #{task_user_connection.user.full_name} [Sapling]", 
        'description' => created_task_description, 
        'due_date'=>task_user_connection.due_date.strftime('%Y-%m-%d')
      })
    }
    let(:updated_task_body){
      JSON.generate({
        'short_description'=>"#{task.name} for #{tuc.user.full_name} [Sapling]", 
        'description' => updated_task_description, 
        'due_date' => tuc.due_date.strftime('%Y-%m-%d')
      })
    }
    let(:request_header){
      {
        'Accept' => 'application/json',
        'Authorization' => 'Basic dGVzdDoxMjM=',
        'Content-Type' => 'application/json',
        'Host' => 'test.domain'
      }
    }

    before(:all) do
      WebMock.disable_net_connect!
    end
    before(:example) do
      service_now_instance.reload
    end

    context 'create_task' do
      it 'should create service now task successfully' do
        stub_request(:post, url).
        with(body: created_task_body, headers: request_header).
        to_return(status: 201, body: %Q({"result":{"sys_id": "123456"}}), headers: {})

        Productivity::ServiceNow::ManageSaplingTaskInServiceNow.new(user.id, company.id, [task_user_connection.id]).perform('create')
        expect(task_user_connection.reload.service_now_id).to eq('123456')
      end

      it 'should not create service now task' do
        stub_request(:post, url).
        with(body: created_task_body, headers: request_header).
        to_return(status: 500, body: '', headers: {})

        Productivity::ServiceNow::ManageSaplingTaskInServiceNow.new(user.id, company.id, [task_user_connection.id]).perform('create')
        expect(last_log_in_company.state).to eq(500)
        expect(last_log_in_company.action).to eq('Create')
      end
    end

    context 'update_task' do
      it 'should update service now task successfully' do
        stub_request(:put, url_with_service_now_id).
        with(body: updated_task_body, headers: request_header).
        to_return(status: 200, body: %Q({"result":{"sys_id": "123","description":"test_new"}}), headers: {})

        Productivity::ServiceNow::ManageSaplingTaskInServiceNow.new(nil, company.id, task.id).perform('update')
        expect(last_log_in_company.state).to eq(200)
        expect(last_log_in_company.action).to eq('Update Name and Description - Success')
      end

      it 'should not update service now task' do
        stub_request(:put, url_with_service_now_id).
        with(body: updated_task_body, headers: request_header).
        to_return(status: 500, body: '', headers: {})

        Productivity::ServiceNow::ManageSaplingTaskInServiceNow.new(nil, company.id, task.id).perform('update')
        expect(last_log_in_company.state).to eq(500)
        expect(last_log_in_company.action).to eq('Update Name and Description - Failure')
      end
    end

    context 'update_task_state' do
      it 'should update service now task state successfully' do
        stub_request(:put, url_with_service_now_id).
        with(body: JSON.generate({'state' => 3}), headers: request_header).
        to_return(status: 200, body: %Q({"result":{"sys_id": "123","state":"3"}}), headers: {})

        Productivity::ServiceNow::ManageSaplingTaskInServiceNow.new(nil, company.id, tuc.id).perform('update_status')
        expect(last_log_in_company.state).to eq(200)
        expect(last_log_in_company.action).to eq('Update task state - Success')
      end

      it 'should not update service now task state' do
        stub_request(:put, url_with_service_now_id).
        with(body: JSON.generate({'state' => 3}), headers: request_header).
        to_return(status: 500, body: '', headers: {})

        Productivity::ServiceNow::ManageSaplingTaskInServiceNow.new(nil, company.id, tuc.id).perform('update_status')
        expect(last_log_in_company.state).to eq(500)
        expect(last_log_in_company.action).to eq('Update task state - Failure')
      end
    end

    context 'destroy_task' do
      it 'should delete service now task successfully' do
        stub_request(:delete, url_with_service_now_id).
        with(headers: request_header).
        to_return(status: 204, body: '', headers: {})

        Productivity::ServiceNow::ManageSaplingTaskInServiceNow.new(nil, company.id, tuc.service_now_id).perform('delete')
        expect(last_log_in_company.state).to eq(204)
        expect(last_log_in_company.action).to eq('Delete')
      end

      it 'should not delete service now task' do
        stub_request(:delete, url_with_service_now_id).
        with(headers: request_header).
        to_return(status: 500, body: '', headers: {})

        Productivity::ServiceNow::ManageSaplingTaskInServiceNow.new(nil, company.id, tuc.service_now_id).perform('delete')
        expect(last_log_in_company.state).to eq(500)
        expect(last_log_in_company.action).to eq('Delete')
      end
    end

    context 'completed_service_now_tasks' do
      it 'should update all the completed tasks from service now' do
        stub_request(:get, "#{url}?&state=3").
          with(headers: request_header).
          to_return(status: 200, body: %Q({"result": [{"sys_id": "234", "closed_at":"#{(DateTime.now - 5.minutes)}"}, {"sys_id": "567", "closed_at":"#{(DateTime.now - 10.minutes)}"}]}))

        tucs = tucs_service_now
        Productivity::ServiceNow::ManageServiceNowTaskInSapling.call(company.id)
        tucs = tucs_service_now.map { |tuc| tuc.reload }
        expect(tucs.first.reload.state).to eq('completed')
        expect(tucs.second.state).to eq('completed')
      end

      it 'should only update the completed task from service now' do
        stub_request(:get, "#{url}?&state=3").
          with(headers: request_header).
          to_return(status: 200, body: %Q({"result": [{"sys_id": "234", "closed_at":"#{(DateTime.now - 5.minutes)}"}]}))

        tucs = tucs_service_now
        Productivity::ServiceNow::ManageServiceNowTaskInSapling.call(company.id)
        tucs = tucs_service_now.map { |tuc| tuc.reload }
        expect(tucs.first.reload.state).to eq('completed')
        expect(tucs.second.state).to_not eq('completed')
      end

      it 'should not update the completed task from service now' do
        stub_request(:get, "#{url}?&state=3").
          with(headers: request_header).
          to_return(status: 500, body: "")

        tucs = tucs_service_now
        Productivity::ServiceNow::ManageServiceNowTaskInSapling.call(company.id)
        tucs = tucs_service_now.map { |tuc| tuc.reload }
        expect(last_log_in_company.state).to eq(500)
        expect(last_log_in_company.action).to eq('Complete Task From ServiceNow - Failure')
        
      end
    end
  end
end
