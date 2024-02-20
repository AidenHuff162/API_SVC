require 'rails_helper'

RSpec.describe PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive do
  let(:company) { create(:company, subdomain: 'fifteenfive-company') }
  let(:company2) { create(:company, subdomain: 'fifteenfive-company-2') }
  let(:location) { create(:location, company: company) }
  let!(:fifteen_five) { create(:fifteen_five_integration, company: company) }
  let!(:invalid_fifteen_five) { create(:fifteen_five_integration, company: company2) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company, location: location) } 
  let(:user2) { create(:user, state: :active, current_stage: :registered, company: company2) } 
  let(:update_user) { create(:user, state: :active, current_stage: :registered, company: company, location: location, fifteen_five_id: 123) } 
  
  before (:all) do
    @create_action = 'create'
    @update_action = 'update'
    @delete_action = 'delete'
  end

  describe '#perform' do
    before(:each) do
      allow_any_instance_of(IntegrationInstance).to receive(:access_token).and_return('token')
      allow_any_instance_of(IntegrationInstance).to receive(:subdomain).and_return('subdomain')
      allow_any_instance_of(IntegrationInstance).to receive(:can_delete_profile).and_return(true)
    end
    context 'action is invalid' do
      it 'should return 404 if action is invalid' do
        ::PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive.new(user).perform(nil)
        logging = company.loggings.where(integration_name: 'Fifteen Five').last
        expect(logging.state).to eq(404)
        expect(logging.action).to eq('Action missing')
      end
    end

    context 'integration is invalid' do
      it 'should return 404 if integration is invalid' do
        allow_any_instance_of(IntegrationInstance).to receive(:access_token).and_return(nil)
        PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive.new(user2).perform(@create_action)
        logging = company2.loggings.where(integration_name: 'Fifteen Five').last
        expect(logging.state).to eq(404)
        expect(logging.action).to eq("Fifteen Five credentials missing - #{@create_action}")
      end
    end

    context 'user is invalid' do
      it 'should return 424 if user is invalid' do
        fifteen_five.update_column(:filters, {"location_id"=>[200], "team_id"=>["all"], "employee_type"=>["all"]})
        user.update_column(:location_id, location.id)
        ::PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive.new(user.reload).perform(@create_action)
        logging = company.loggings.where(integration_name: 'Fifteen Five').last
        expect(logging.state).to eq(424)
        expect(logging.action).to eq("Fifteen Five filters are not for user (#{user.id}) - #{@create_action}")
      end
    end
    
    context 'action is valid' do
      before(:all) do
        WebMock.disable_net_connect!
        parameter_mapping = ::PerformanceManagementIntegrationsService::FifteenFive::ParamsMapper.new.build_parameter_mappings
        @data_builder = ::PerformanceManagementIntegrationsService::FifteenFive::DataBuilder.new(parameter_mapping)
        @params_builder = ::PerformanceManagementIntegrationsService::FifteenFive::ParamsBuilder.new(parameter_mapping)
      end
      
      context 'Create Sapling Profile In FifteenFive' do
        before(:each) do
          request_data = @data_builder.build_create_profile_data(user)
          @request_params = @params_builder.build_create_profile_params(request_data)
          @response = JSON.generate({'id': 123})
        end

        it 'should create user in fifteen five' do
          stub_request(:post, "https://#{fifteen_five.subdomain}.15five.com/scim/v2/Users").
            to_return(status: 201, body: @response)
          ::PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive.new(user).perform(@create_action)
          expect(user.reload.fifteen_five_id).to eq('123')
        end

        it 'should not create user in fifteen five if data is invalid' do
          stub_request(:post, "https://#{fifteen_five.subdomain}.15five.com/scim/v2/Users").
            to_return(status: 400, body: @response)
          ::PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive.new(user).perform(@create_action)
          expect(user.reload.fifteen_five_id).to eq(nil)
        end

        it 'should not create user in fifteen five if there is some excpetion in creating data' do
          ::PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive.new(user).perform(@create_action)
          expect(user.reload.fifteen_five_id).to eq(nil)
        end
      end

      context 'Update Sapling Profile In FifteenFive' do
        it 'should update user in fifteen five' do
          request_data = @data_builder.build_update_profile_data(update_user, 'scim')
          request_params = @params_builder.build_update_profile_params(request_data)
          stub_request(:put, "https://#{fifteen_five.subdomain}.15five.com/scim/v2/Users/#{update_user.fifteen_five_id}").
            to_return(status: 200, body: '')
          ::PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive.new(update_user).perform(@update_action)
          logging = company.loggings.where(integration_name: 'Fifteen Five').last
          expect(logging.state).to eq(200)
          expect(logging.action).to eq('Update user in fifteen five (SCIM) - Success')
        end

        it 'should not update user in fifteen five if data is not valid' do
          request_data = @data_builder.build_update_profile_data(update_user, nil, 'api')
          request_params = @params_builder.build_update_profile_params(request_data)
          stub_request(:put, "https://#{fifteen_five.subdomain}.15five.com/scim/v2/Users/#{update_user.fifteen_five_id}").
            to_return(status: 400, body: '')
          ::PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive.new(update_user).perform(@update_action)
          logging = company.loggings.where(integration_name: 'Fifteen Five').last
          expect(logging.state).to eq(400)
          expect(logging.action).to eq('Update user in fifteen five (SCIM) - Failure')
        end

        it 'should not update user in fifteen five if there is some excpetion during making request' do
          ::PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive.new(update_user).perform(@update_action)
          logging = company.loggings.where(integration_name: 'Fifteen Five').last
          expect(logging.state).to eq(500)
          expect(logging.action).to eq('Update user in fifteen five - Failure')
        end
      end
      
      context 'Delete Sapling Profile In FifteenFive' do
        it 'should delete user in fifteen five' do
          stub_request(:delete, "https://#{fifteen_five.subdomain}.15five.com/scim/v2/Users/#{update_user.fifteen_five_id}").
            to_return(status: 204, body: '')
          ::PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive.new(update_user).perform(@delete_action)
          logging = company.loggings.where(integration_name: 'Fifteen Five').last
          expect(logging.state).to eq(204)
          expect(logging.action).to eq('Delete user in fifteen five - Success')
        end
        
        it 'should not delete user in fifteen five if fifteen five id is invalid' do
          stub_request(:delete, "https://#{fifteen_five.subdomain}.15five.com/scim/v2/Users/#{update_user.fifteen_five_id}").
            to_return(status: 404, body: '')
          ::PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive.new(update_user).perform(@delete_action)
          logging = company.loggings.where(integration_name: 'Fifteen Five').last
          expect(logging.state).to eq(404)
          expect(logging.action).to eq('Delete user in fifteen five - Failure')
        end

        it 'should not delete user in fifteen five there is some excpetion while deleting' do
          ::PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive.new(update_user).perform(@delete_action)
          logging = company.loggings.where(integration_name: 'Fifteen Five').last
          expect(logging.state).to eq(500)
          expect(logging.action).to eq('Delete user in fifteen five - Failure')
        end
      end
    end

  end
end