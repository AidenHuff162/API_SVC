require 'rails_helper'

RSpec.describe PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon do
  let(:company) { create(:company, subdomain: 'peakon-company') }
  let(:company2) { create(:company, subdomain: 'peakon-company-2') }
  let(:location) { create(:location, company: company) }
  let!(:peakon) { create(:peakon_integration, company: company)}
  let!(:invalid_peakon) { create(:peakon_integration, company: company2) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company, location: location) } 
  let(:user2) { create(:user, state: :active, current_stage: :registered, company: company2) } 
  let(:update_user) { create(:user, state: :active, current_stage: :registered, company: company, location: location, peakon_id: 123) } 
  let(:phone_field) { create(:custom_field, name: 'mobile phone number', company: company) } 
  let!(:custom_field_value) { create(:custom_field_value, custom_field: phone_field, user: user) } 

  before (:all) do
    @create_action = 'create'
    @update_action = 'update'
    @delete_action = 'delete'
  end

  describe '#perform' do
    before do
      allow_any_instance_of(IntegrationInstance).to receive(:access_token).and_return('token')
      allow_any_instance_of(IntegrationInstance).to receive(:can_delete_profile).and_return(true)
    end

    context 'action is invalid' do
      it 'should return 404 if action is invalid' do
        ::PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon.new(user).perform(nil)
        logging = company.loggings.where(integration_name: 'Peakon').last
        expect(logging.state).to eq(404)
        expect(logging.action).to eq('Action missing')
      end
    end

    context 'integration is invalid' do
      it 'should return 404 if integration is invalid' do
        allow_any_instance_of(IntegrationInstance).to receive(:access_token).and_return(nil)
        ::PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon.new(user2).perform(@create_action)
        logging = company2.loggings.where(integration_name: 'Peakon').last
        expect(logging.state).to eq(404)
        expect(logging.action).to eq("Peakon credentials missing - #{@create_action}")
      end
    end

    context 'user is invalid' do
      it 'should reutn 424 if user is invalid' do
        user.update_column(:location_id, location.id)
        peakon.update_column(:filters, {"location_id"=>[location.id + 1], "team_id"=>["all"], "employee_type"=>["all"]})
        ::PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon.new(user.reload).perform(@create_action)
        logging = company.loggings.where(integration_name: 'Peakon').last
        expect(logging.state).to eq(424)
        expect(logging.action).to eq("Peakon filters are not for user (#{user.id}) - #{@create_action}")
      end
    end

    context 'action is valid' do
      before(:all) do
        WebMock.disable_net_connect!
        parameter_mapping = ::PerformanceManagementIntegrationsService::Peakon::ParamsMapper.new.build_parameter_mappings
        @data_builder = ::PerformanceManagementIntegrationsService::Peakon::DataBuilder.new(parameter_mapping)
        @params_builder = ::PerformanceManagementIntegrationsService::Peakon::ParamsBuilder.new(parameter_mapping)
      end
      
      context 'Create Sapling Profile In Peakon' do
        before(:each) do
          request_data = @data_builder.build_create_profile_data(user)
          @request_params = @params_builder.build_create_profile_params(request_data)
          @response = JSON.generate({'id': 123})
        end

        it 'should create user in Peakon' do
          stub_request(:post, "https://api.peakon.com/scim/v2/Users").
            with(
              body: JSON.generate(@request_params),
              headers: {
              'Accept'=>'*/*',
              'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Authorization'=>"Bearer #{peakon.access_token}",
              'Content-Type'=>'application/scim+json',
              'Host'=>'api.peakon.com',
              'User-Agent'=>'Ruby'
            }).
            to_return(status: 201, body: @response)
          ::PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon.new(user).perform(@create_action)
          expect(user.reload.peakon_id).to eq('123')
        end

        it 'should not create user in Peakon if data is invalid' do
          stub_request(:post, "https://api.peakon.com/scim/v2/Users").
            with(
              body: JSON.generate(@request_params),
              headers: {
              'Accept'=>'*/*',
              'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Authorization'=>"Bearer #{peakon.access_token}",
              'Content-Type'=>'application/scim+json',
              'Host'=>'api.peakon.com',
              'User-Agent'=>'Ruby'
            }).
            to_return(status: 400, body: @response)
          ::PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon.new(user).perform(@create_action)
          expect(user.reload.peakon_id).to eq(nil)
        end

        it 'should not create user in Peakon if there is some excpetion in creating data' do
          ::PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon.new(user).perform(@create_action)
          expect(user.reload.peakon_id).to eq(nil)
        end
      end

      context 'Update Sapling Profile In Peakon' do
        it 'should update user in Peakon' do
          request_data = @data_builder.build_update_profile_data(update_user, ['team id'])
          request_params = @params_builder.build_update_profile_params(request_data)
          stub_request(:put, "https://api.peakon.com/scim/v2/Users/#{update_user.peakon_id}").
            with(
              body: "urn%3Aietf%3Aparams%3Ascim%3Aschemas%3Aextension%3Apeakon%3A2.0%3AUser%5BDepartment%5D=&schemas%5B%5D=urn%3Aietf%3Aparams%3Ascim%3Aschemas%3Acore%3A2.0%3AUser&schemas%5B%5D=urn%3Aietf%3Aparams%3Ascim%3Aschemas%3Aextension%3Apeakon%3A2.0%3AUser",
              headers: {
              'Accept'=>'application/scim+json',
              'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Authorization'=>'Bearer token',
              'Content-Type'=>'application/scim+json',
              'User-Agent'=>'Ruby'
              }).
            to_return(status: 200, body: "", headers: {})
          ::PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon.new(update_user).perform(@update_action, ['team id'])
          logging = company.loggings.where(integration_name: 'Peakon').last
          expect(logging.state).to eq(200)
          expect(logging.action).to eq('Update user in peakon - Success')
        end

        it 'should not update user in Peakon if data is not valid' do
          request_data = @data_builder.build_update_profile_data(update_user, ['team id'])
          request_params = @params_builder.build_update_profile_params(request_data)
          stub_request(:put, "https://api.peakon.com/scim/v2/Users/#{update_user.peakon_id}").
            with(
              body: "urn%3Aietf%3Aparams%3Ascim%3Aschemas%3Aextension%3Apeakon%3A2.0%3AUser%5BDepartment%5D=&schemas%5B%5D=urn%3Aietf%3Aparams%3Ascim%3Aschemas%3Acore%3A2.0%3AUser&schemas%5B%5D=urn%3Aietf%3Aparams%3Ascim%3Aschemas%3Aextension%3Apeakon%3A2.0%3AUser",
              headers: {
              'Accept'=>'application/scim+json',
              'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Authorization'=>'Bearer token',
              'Content-Type'=>'application/scim+json',
              'User-Agent'=>'Ruby'
              }).
            to_return(status: 400, body: "", headers: {})
          ::PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon.new(update_user).perform(@update_action, ['team id'])
          logging = company.loggings.where(integration_name: 'Peakon').last
          expect(logging.state).to eq(400)
          expect(logging.action).to eq('Update user in peakon - Failure')
        end

        it 'should not update user in Peakon if there is some excpetion during making request' do
          ::PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon.new(update_user).perform(@update_action, ['team id'])
          logging = company.loggings.where(integration_name: 'Peakon').last
          expect(logging.state).to eq(500)
          expect(logging.action).to eq('Update user in peakon - Failure')
        end
      end
      
      context 'Delete Sapling Profile In Peakon' do
        it 'should delete user in Peakon' do
          stub_request(:delete, "https://api.peakon.com/scim/v2/Users/#{update_user.peakon_id}").
            with(
              headers: {
              'Authorization'=>"Bearer #{peakon.access_token}"
            }).
            to_return(status: 204, body: '')
          ::PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon.new(update_user).perform(@delete_action)
          logging = company.loggings.where(integration_name: 'Peakon').last
          expect(logging.state).to eq(204)
          expect(logging.action).to eq('Delete user in Peakon - Success')
        end
        
        it 'should not delete user in Peakon if Peakon id is invalid' do
          stub_request(:delete, "https://api.peakon.com/scim/v2/Users/#{update_user.peakon_id}").
            with(
              headers: {
              'Authorization'=>"Bearer #{peakon.access_token}"
            }).
            to_return(status: 404, body: '')
          ::PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon.new(update_user).perform(@delete_action)
          logging = company.loggings.where(integration_name: 'Peakon').last
          expect(logging.state).to eq(404)
          expect(logging.action).to eq('Delete user in Peakon - Failure')
        end

        it 'should not delete user in Peakon there is some excpetion while deleting' do
          ::PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon.new(update_user).perform(@delete_action)
          logging = company.loggings.where(integration_name: 'Peakon').last
          expect(logging.state).to eq(500)
          expect(logging.action).to eq('Delete user in Peakon - Failure')
        end
      end
    end
  end
end