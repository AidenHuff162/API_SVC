require 'rails_helper'

RSpec.describe HrisIntegrationsService::Xero::CreateLeaveTypesInXero do
  let(:company) { create(:company) }
  let(:xero) { create(:xero_integration, company: company, access_token: SecureRandom.hex, subdomain: 'test', company_code: '123', expires_in: Time.now.utc+55.minutes) }
  let(:pto_policy) { create(:default_pto_policy, company: company) } 

  before(:all) do
    WebMock.disable_net_connect!
  end

  before(:each) do
    allow_any_instance_of(HrisIntegrationsService::Xero::Helper).to receive(:refresh_token).and_return(xero)
    allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:authenticate_access_token).and_return(true)
  end


  describe '#create_leave_type' do
    context 'Create Leave Type In Xero' do
      it 'should create leave type in Xero' do
        ok = double('ok?', ok?: true)
        body = double('body', :body => JSON.generate({'PayItems'=>{'LeaveTypes'=>['LeaveTypeID'=>'12']}}), :message => 'OK', :code => 200, :status => ok, :ok? => true) 
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(body)
        ::HrisIntegrationsService::Xero::CreateLeaveTypesInXero.new(pto_policy).create_leave_type
        expect(pto_policy.reload.xero_leave_type_id).to eq('12')
      end

      it 'should not create leave type if data is invalid' do
        body = double('body', :message => 'Unprocessible entity', :code => 422)
        response = double('response', response: body)
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(response)

        ::HrisIntegrationsService::Xero::CreateLeaveTypesInXero.new(pto_policy).create_leave_type
        expect(pto_policy.reload.xero_leave_type_id).to eq(nil)
      end

      it 'should not create user in fifteen five if there is some excpetion in creating data' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_raise(Exception)
        ::HrisIntegrationsService::Xero::CreateLeaveTypesInXero.new(pto_policy).create_leave_type
        expect(pto_policy.reload.xero_leave_type_id).to eq(nil)
      end
    end
  end
end 