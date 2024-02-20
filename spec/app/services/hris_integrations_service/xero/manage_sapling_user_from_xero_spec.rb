require 'rails_helper'

RSpec.describe HrisIntegrationsService::Xero::ManageSaplingUserFromXero do
  let(:company) { create(:company) }
  let(:xero) { create(:xero_integration, company: company, access_token: SecureRandom.hex, subdomain: 'test', company_code: '123', expires_in: Time.now.utc+55.minutes) }

  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) } 
  let(:user2) { create(:user, state: :active, current_stage: :registered, company: company) }

  before(:all) do
    WebMock.disable_net_connect!
  end

  before(:each) do
    allow_any_instance_of(HrisIntegrationsService::Xero::Helper).to receive(:refresh_token).and_return(xero)
    allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:authenticate_access_token).and_return(true)
  end

  describe '#perform' do
    context 'Update Xero Profile In sapling' do
      it 'should update user in Sapling' do
        response = {'Employees'=>[{'EmployeeID'=>'456', 'Email'=>user.email}], 'status' => 'OK'}
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:get).and_return(response)
        ::HrisIntegrationsService::Xero::ManageSaplingUserFromXero.new(company).perform
        expect(user.reload.xero_id).to eq('456')
      end
      it 'should mot map profile if user is not present' do
        response = {'Employees'=>[{'EmployeeID'=>'456', 'Email'=>"123#{user.email}"}], 'status' => 'OK'}
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:get).and_return(response)
        ::HrisIntegrationsService::Xero::ManageSaplingUserFromXero.new(company).perform
        expect(user.reload.fifteen_five_id).to eq(nil)
      end

      it 'should mot map profile if two users has same profile' do
        user2.update_column(:personal_email, user.email)
        response = {'Employees'=>[{'EmployeeID'=>'456', 'Email'=>user.email}], 'status' => 'OK'}
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:get).and_return(response)
        ::HrisIntegrationsService::Xero::ManageSaplingUserFromXero.new(company).perform
        expect(user.reload.fifteen_five_id).to eq(nil)
      end

      it 'should mot map profile if there is some exception while fetching data' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:get).and_raise(Exception)
        ::HrisIntegrationsService::Xero::ManageSaplingUserFromXero.new(company).perform
        expect(user.reload.fifteen_five_id).to eq(nil)
      end
    end
  end
end