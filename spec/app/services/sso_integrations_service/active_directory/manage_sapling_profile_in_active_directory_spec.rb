require 'rails_helper'

RSpec.describe SsoIntegrationsService::ActiveDirectory::ManageSaplingProfileInActiveDirectory do
  let(:company) { create(:company) }
  let(:company2) { create(:company) }

  let!(:adfs) { create(:adfs_productivity_integration_instance, company: company) }
  let(:invalid_adfs) { create(:adfs_productivity_integration_instance, company: company2 ) }

  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) } 
  let(:user2) { create(:user, state: :active, current_stage: :registered, company: company2) } 
  let(:update_user) { create(:user, state: :active, current_stage: :registered, company: company, active_directory_object_id: '123') } 

  before(:all) do
    @create_action = 'create_and_update'
    @update_action = 'update'
    WebMock.disable_net_connect!
    parameter_mapping = ::SsoIntegrationsService::ActiveDirectory::ParamsMapper.new.build_parameter_mappings
    @data_builder = ::SsoIntegrationsService::ActiveDirectory::DataBuilder.new(parameter_mapping)
    @params_builder = ::SsoIntegrationsService::ActiveDirectory::ParamsBuilder.new(parameter_mapping)
  end

  describe '#perform' do
    context 'action is invalid' do
      it 'should return 404 if action is invalid' do
        ::SsoIntegrationsService::ActiveDirectory::ManageSaplingProfileInActiveDirectory.new(user).perform(nil)
        expect(company.loggings.where(integration_name: 'Active Directory').last.action.include?('Action missing')).to eq (true)
      end
    end

    context 'integration is invalid' do
      it 'should return 400 if access_token is invalid' do
        adfs.expires_in(Time.now.utc + 10.minutes)
        allow_any_instance_of(SsoIntegrationsService::ActiveDirectory::AuthenticateApplication).to receive(:reauthorize).and_return('failed')
        ::SsoIntegrationsService::ActiveDirectory::ManageSaplingProfileInActiveDirectory.new(user).perform(@create_action)
        expect(company.loggings.where(integration_name: 'Active Directory').last.action.include?("Active Directory credentials missing - #{@create_action}")).to eq (true)
      end

      it 'should return 404 if integration is invalid' do
        invalid_adfs.reload
        invalid_adfs.integration_credentials.find_by(name: 'Access Token').update(value: nil)
        ::SsoIntegrationsService::ActiveDirectory::ManageSaplingProfileInActiveDirectory.new(user2).perform(@create_action)
        expect(company2.loggings.where(integration_name: 'Active Directory').last.action.include?("Active Directory credentials missing - #{@create_action}")).to eq (true)
      end
    end

    context 'action is valid' do
      context 'Create Sapling Profile In ADFS' do
        before(:each) do
          request_data = @data_builder.build_create_profile_data(user)
          @request_params = @params_builder.build_create_profile_params(request_data)
          @response = JSON.generate({'id'=>'123'})
        end

        it 'should create user in ADFS' do
          stub_request(:post, "https://graph.microsoft.com/beta/users").
            with(
             body: JSON.generate(@request_params),
             headers: {
            'Accept'=>'application/json',
            'Authorization'=>"Bearer #{adfs.access_token}",
            'Content-Type'=>'application/json'
            }).
            to_return(status: 201, body: @response)

          allow_any_instance_of(SsoIntegrationsService::ActiveDirectory::ParamsBuilder).to receive(:build_create_profile_params).and_return(@request_params)
          ::SsoIntegrationsService::ActiveDirectory::ManageSaplingProfileInActiveDirectory.new(user).perform(@create_action)
          expect(user.reload.active_directory_object_id).to eq('123')
        end

        it 'should not create user in ADFS if data is invalid' do
          stub_request(:post, "https://graph.microsoft.com/beta/users").
            with(
             body: JSON.generate(@request_params),
             headers: {
            'Accept'=>'application/json',
            'Authorization'=>"Bearer #{adfs.access_token}",
            'Content-Type'=>'application/json'
            }).
            to_return(status: 424, body: @response)
          allow_any_instance_of(SsoIntegrationsService::ActiveDirectory::ParamsBuilder).to receive(:build_create_profile_params).and_return(@request_params)
          ::SsoIntegrationsService::ActiveDirectory::ManageSaplingProfileInActiveDirectory.new(user).perform(@create_action)
          expect(user.reload.active_directory_object_id).to eq(nil)
        end

        it 'should reutrn 500 if there is some exception' do
          ::SsoIntegrationsService::ActiveDirectory::ManageSaplingProfileInActiveDirectory.new(user).perform(@create_action)
          expect(user.reload.active_directory_object_id).to eq(nil)
        end
      end

      context 'Update Sapling Profile In ADFS' do
        before(:each) do
          request_data = @data_builder.build_update_profile_data(update_user, ['state'])
          @request_params = @params_builder.build_update_profile_params(request_data)
          @response = JSON.generate({'id'=>'123'})
        end

        it 'should update user in ADFS' do
          stub_request(:patch, "https://graph.microsoft.com/beta/users/123").
           with(
             body: JSON.generate(@request_params),
             headers: {
            'Accept'=>'application/json',
            'Authorization'=>"Bearer #{adfs.access_token}",
            'Content-Type'=>'application/json'
            }).
            to_return(status: 204, body: @response)
          ::SsoIntegrationsService::ActiveDirectory::ManageSaplingProfileInActiveDirectory.new(update_user).perform(@update_action, ['state'])
          expect(company.loggings.where(integration_name: 'Active Directory').last.action.include?("Update user-#{update_user.id} in active directory - Success")).to eq (true)
        end

        it 'should not update user in ADFS if data is invalid' do
          stub_request(:patch, "https://graph.microsoft.com/beta/users/123").
           with(
             body: JSON.generate(@request_params),
             headers: {
            'Accept'=>'application/json',
            'Authorization'=>"Bearer #{adfs.access_token}",
            'Content-Type'=>'application/json'
            }).
            to_return(status: 424, body: @response)
          ::SsoIntegrationsService::ActiveDirectory::ManageSaplingProfileInActiveDirectory.new(update_user).perform(@update_action, ['state'])
          expect(company.loggings.where(integration_name: 'Active Directory').last.action.include?("Update user-#{update_user.id} in active directory - Failure")).to eq (true)
        end

        it 'should reutrn 500 if there is some exception' do
          ::SsoIntegrationsService::ActiveDirectory::ManageSaplingProfileInActiveDirectory.new(update_user).perform(@update_action, ['state'])
          expect(company.loggings.where(integration_name: 'Active Directory').last.action.include?("Update user-#{update_user.id} in active directory - Failure")).to eq (true)
        end
      end
    end
  end
end 