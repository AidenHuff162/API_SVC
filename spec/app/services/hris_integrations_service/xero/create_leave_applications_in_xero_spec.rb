require 'rails_helper'

RSpec.describe HrisIntegrationsService::Xero::CreateLeaveApplicationsInXero do
  let(:company) { create(:company) }
  let(:xero_integration_inventory) {create(:integration_inventory, display_name: 'Xero', status: 2, category: 0, data_direction: 1, enable_filters: false, api_identifier: 'xero')}
  let(:xero) {create(:integration_instance, api_identifier: 'xero', state: 'active', integration_inventory_id: xero_integration_inventory.id, name: 'Instance no.1', company_id: company.id)}
  let(:pto_policy) { create(:default_pto_policy, xero_leave_type_id: '123', company: company) } 
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company, start_date: 5.years.ago) } 
  let(:pto_reqeust) { create(:default_pto_request, user: user, pto_policy: pto_policy) } 

  before(:all) do
    WebMock.disable_net_connect!
  end

  before(:each) do
    User.current = user
    allow_any_instance_of(HrisIntegrationsService::Xero::Helper).to receive(:refresh_token).and_return(xero)
    allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:authenticate_access_token).and_return(true)
  end

  describe '#create_leave_application' do
    context 'Create Leave application In Xero' do
      it 'should create leave application in Xero if leave type already assigned' do
        ok = double('ok?', ok?: true)
        xero.stub(:access_token) { '123' }
        xero.stub(:payroll_calendar) { '123' }
        stub_request(:get, "https://api.xero.com/payroll.xro/1.0/Employees/").
          with(
            headers: {
            'Accept'=>'application/json',
            'Authorization'=>'Bearer'
            }).
          to_return(status: 200, body: JSON.generate({'Employees'=>[{'PayTemplate'=>{'LeaveLines'=>[{'LeaveTypeID'=>'123'}]}}], 'Status' => 'OK', 'ok?' => 'true'}), headers: {})

        stub_request(:get, "https://api.xero.com/payroll.xro/1.0/PayrollCalendars/").
          with(
          headers: {
            'Accept'=>'application/json',
            'Authorization'=>'Bearer'
          }).
        to_return(status: 200, body: JSON.generate({'PayrollCalendars'=>[{'CalendarType'=>'WEEKLY', 'StartDate'=>'/Date(1573603200000+0000)/', 'ReferenceDate'=>'/Date(1573603200000+0000)/'}], 'Status' => 'OK', 'ok?' => 'true'}), headers: {})

        response = double('body', :body => JSON.generate({'PayItems'=>{'LeaveApplication'=>[{'LeaveApplicationID'=>'12'}]}}), :message => 'OK', :code => 200, :status => ok, :ok? => true)
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(response)

        HrisIntegrationsService::Xero::CreateLeaveApplicationsInXero.new(pto_reqeust).create_leave_application
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Create Leave Applications in Xero - SUCCESS')
      end

      it 'should not create leave type if data is invalid' do
        ok = double('ok?', ok?: false)
        xero.stub(:access_token) { '123' }
        xero.stub(:payroll_calendar) { '123' }
        response = double('body', :body => JSON.generate({'PayItems'=>{'LeaveApplication'=>[{'LeaveApplicationID'=>'12'}]}}), :message => 'Unprocessible entity', :code => 422, :status => ok, :ok? => false)
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(response)

        stub_request(:get, "https://api.xero.com/payroll.xro/1.0/Employees/").
          with(
            headers: {
            'Accept'=>'application/json',
            'Authorization'=>'Bearer'
            }).
          to_return(status: 200, body: JSON.generate({'Employees'=>[{'PayTemplate'=>{'LeaveLines'=>['LeaveTypeID'=>'123']}}], 'Status' => 'OK', 'ok?' => 'false'}), headers: {})

        stub_request(:get, "https://api.xero.com/payroll.xro/1.0/PayrollCalendars/").
          with(
          headers: {
            'Accept'=>'application/json',
            'Authorization'=>'Bearer'
          }).
        to_return(status: 200, body: JSON.generate({'PayrollCalendars'=>[{'CalendarType'=>'WEEKLY', 'StartDate'=>'/Date(1573603200000+0000)/', 'ReferenceDate'=>'/Date(1573603200000+0000)/'}], 'Status' => 'OK', 'ok?' => 'false'}), headers: {})

        response = {'PayrollCalendars'=>[{'CalendarType'=>'WEEKLY', 'StartDate'=>'/Date(1573603200000+0000)/', 'ReferenceDate'=>'/Date(1573603200000+0000)/'}], 'Status' => 'OK', 'ok?' => 'false'} 
        response1 = {'Employees'=>[{'PayTemplate'=>{'LeaveLines'=>['LeaveTypeID'=>'123']}}], 'Status' => 'OK', 'ok?' => 'false'}
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:get).and_return(response, response1)

        HrisIntegrationsService::Xero::CreateLeaveApplicationsInXero.new(pto_reqeust).create_leave_application
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(422)
        expect(logging.action).to eq('Create Leave Applications in Xero - Failure')
      end

      it 'should not create leave application in xero if there is some excpetion in creating data' do
        ok = double('ok?', ok?: true)
        response = {'Employees'=>[{'PayTemplate'=>{'LeaveLines'=>['LeaveTypeID'=>'123']}}], 'Status' => 'OK', :status => ok, :ok? => true}
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:get).and_return(response)

        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_raise(Exception)
        ::HrisIntegrationsService::Xero::CreateLeaveApplicationsInXero.new(pto_reqeust).create_leave_application
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Create Leave Applications in Xero - Failure')
      end

       it 'should create leave application in Xero and assign leave type' do
        ok = double('ok?', ok?: true)
        response = double('body', :body => JSON.generate({'PayItems'=>{'LeaveApplication'=>[{'LeaveApplicationID'=>'12'}]}}), :message => 'OK', :code => 200, :status => ok, :ok? => true)
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(response)

        response = {'Employees'=>[{'PayTemplate'=>{'LeaveLines'=>[{'LeaveTypeID'=>'456'}]}}], 'Status' => 'OK', 'ok?' => 'true'}
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:get).and_return(response)

        HrisIntegrationsService::Xero::CreateLeaveApplicationsInXero.new(pto_reqeust).create_leave_application
        logging = company.loggings.where(integration_name: 'Xero').first
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Assign Leave Type in Xero - SUCCESS')
      end

      it 'should not assign leave type if data is invalid' do
        ok = double('ok?', ok?: false)
        response = double('body', :body => JSON.generate({'PayItems'=>{'LeaveApplication'=>[{'LeaveApplicationID'=>'12'}]}}), :message => 'Unprocessible entity', :code => 422, :status => ok, :ok? => false)
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(response)

        response = {'Employees'=>[{'PayTemplate'=>{'LeaveLines'=>[{'LeaveTypeID'=>'456'}]}}], 'Status' => 'OK', 'ok?' => 'false'}
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:get).and_return(response)

        HrisIntegrationsService::Xero::CreateLeaveApplicationsInXero.new(pto_reqeust).create_leave_application
        logging = company.loggings.where(integration_name: 'Xero').first
        expect(logging.state).to eq(422)
        expect(logging.action).to eq('Assign Leave Type in Xero - Failure')
      end

      it 'should not create leave application in xero if there is some excpetion in creating data' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:get).and_raise(Exception)
        ::HrisIntegrationsService::Xero::CreateLeaveApplicationsInXero.new(pto_reqeust).create_leave_application
        logging = company.loggings.where(integration_name: 'Xero', state: 500, action: 'Create Leave Applications in Xero - Failure').take
        expect(logging.present?).to eq(true)
      end
    end
  end
end 