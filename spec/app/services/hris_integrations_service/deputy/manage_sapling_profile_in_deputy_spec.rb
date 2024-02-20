require 'rails_helper'

RSpec.describe HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy do
  let(:company) { create(:company, subdomain: 'deputy-company') }
  let(:company2) { create(:company, subdomain: 'deputy-company-2') }
  let(:company3) { create(:company, subdomain: 'deputy-company-without-table', is_using_custom_table: false) }
  let(:location) { create(:location, company: company) }
  let!(:deputy) { create(:deputy_integration, company: company) }
  let!(:invalid_deputy) { create(:deputy_integration, company: company2) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company, location: location) } 
  let(:user2) { create(:user, state: :active, current_stage: :registered, company: company2) } 
  let(:update_user) { create(:user, state: :active, current_stage: :registered, company: company, location: location, deputy_id: 123) } 
  let(:update_user_2) { create(:user, state: :active, current_stage: :registered, company: company3, location: location, deputy_id: 123) } 
  let(:user3) { create(:user, state: :active, current_stage: :registered, company: company3) } 
  let(:deputy3) { create(:deputy_integration, company: company3) }

  before (:all) do
    @create_action = 'create'
    @update_action = 'update'
    @delete_action = 'delete'
    @terminate_action = 'terminate'
    @rehire_action = 'rehire'
    @rehire_and_update = 'rehire_and_update'
    @terminate_and_delete = 'terminate_and_delete'
  end
  
  before(:each) do
    allow_any_instance_of(IntegrationInstance).to receive(:client_id).and_return('id')
    allow_any_instance_of(IntegrationInstance).to receive(:client_secret).and_return('secret')
    allow_any_instance_of(IntegrationInstance).to receive(:client_secret).and_return('secret')
    allow_any_instance_of(IntegrationInstance).to receive(:access_token).and_return('access_token')
    allow_any_instance_of(IntegrationInstance).to receive(:refresh_token).and_return('refresh_token')
    allow_any_instance_of(IntegrationInstance).to receive(:subdomain).and_return('test.domain')
    allow_any_instance_of(IntegrationInstance).to receive(:expires_in).and_return(Time.now.utc + 1.hour)
    allow_any_instance_of(IntegrationInstance).to receive(:can_delete_profile).and_return(true)
  end

  describe '#perform' do
    context 'action is invalid' do
      it 'should return 404 if action is invalid' do
        ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(user).perform(nil)
        logging = company.loggings.where(integration_name: 'Deputy').last
        expect(logging.state).to eq(404)
        expect(logging.action).to eq('Action missing')
      end
    end

    context 'integration is invalid' do
      it 'should return 404 if integration is invalid' do
        allow_any_instance_of(IntegrationInstance).to receive(:access_token).and_return(nil)
        ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(user2).perform(@create_action)
        logging = company2.loggings.where(integration_name: 'Deputy').last
        expect(logging.state).to eq(404)
        expect(logging.action).to eq("Deputy credentials missing - #{@create_action}")
      end
      it 'should return 500 if credentials are expired' do
        allow_any_instance_of(IntegrationInstance).to receive(:expires_in).and_return(Time.now.utc)
        allow_any_instance_of(HrisIntegrationsService::Deputy::AuthenticateApplication).to receive(:reauthorize).and_return('failed')
        ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(user).perform(@create_action)
        logging = company.loggings.where(integration_name: 'Deputy').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq("Deputy credentials missing - #{@create_action}")
      end

      it 'should not return 500 if credentials are reauthorized' do
        allow_any_instance_of(HrisIntegrationsService::Deputy::AuthenticateApplication).to receive(:reauthorize).and_return('true')
        ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(user).perform('test')
        logging = company.loggings.where(integration_name: 'Deputy').last
        expect(logging).to eq(nil)
      end
    end

    context 'user is invalid' do
      it 'should reutn 424 if user is invalid' do
        deputy.update_column(:filters, {"location_id"=>[location.id + 1], "team_id"=>["all"], "employee_type"=>["all"]})
        ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(user.reload).perform(@create_action)
        logging = company.loggings.where(integration_name: 'Deputy').last
        expect(logging.state).to eq(404)
        expect(logging.action).to eq("Deputy filters are not for user(#{user.id}) - #{@create_action}")
      end
    end

    context 'action is valid' do
      before(:all) do
        WebMock.disable_net_connect!
        parameter_mapping = ::HrisIntegrationsService::Deputy::ParamsMapper.new.build_parameter_mappings
        @data_builder = ::HrisIntegrationsService::Deputy::DataBuilder.new(parameter_mapping)
        @params_builder = ::HrisIntegrationsService::Deputy::ParamsBuilder.new(parameter_mapping)
      end
      
      context 'Create Sapling Profile In Deputy' do
        before(:each) do
          gender = company.custom_fields.find_by_name('Gender')
          FactoryGirl.create(:custom_field_value, custom_field: gender, user: user, custom_field_option_id: gender.custom_field_options.take.id)
          request_data = @data_builder.build_create_profile_data(user.reload)
          @request_params = @params_builder.build_create_profile_params(request_data)
          @response = JSON.generate({'Id': 456})
        end

        it 'should create user in Deputy' do
          allow_any_instance_of(HrisIntegrationsService::Deputy::ManageDeputyCompanies).to receive(:create_deputy_company).and_return(true)
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee").
            to_return(status: 200, body: @response)
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(user).perform(@create_action)
          expect(user.reload.deputy_id).to eq('456')
        end

        it 'should not save deputy ID in sapling if the user with same id already present' do
          update_user.update_column(:deputy_id, '456')
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee").
            to_return(status: 200, body: @response)
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(user).perform(@create_action)
          expect(user.reload.deputy_id).to eq(nil)
        end
        it 'should not create user in Deputy if data is invalid' do
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee").
            to_return(status: 400, body: @response)
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(user).perform(@create_action)
          expect(user.reload.peakon_id).to eq(nil)
        end

        it 'should not create user in Peakon if there is some excpetion in creating data' do
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(user).perform(@create_action)
          expect(user.reload.peakon_id).to eq(nil)
        end
      end

      context 'Create Sapling  Profile In Deputy with out custom table' do
        it 'should create user in Deputy with out custom table' do
          FactoryGirl.create(:currency_field_with_value, user: user3, company: company3)
          request_data = @data_builder.build_create_profile_data(user3)
          request_params = @params_builder.build_create_profile_params(request_data)

          stub_request(:post, "https://#{deputy3.subdomain}/api/v1/supervise/employee").
            to_return(status: 200, body: JSON.generate({'Id': 456}))
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(user3).perform(@create_action)
          expect(user3.reload.deputy_id).to eq('456')
        end
      end

      context 'Update Sapling Profile In Deputy' do
        it 'should update user in Deputy' do
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee/#{update_user.deputy_id}").
            to_return(status: 200, body: JSON.generate({'Id': 123}))
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@update_action, ['first name'])
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(200)
          expect(logging.action).to eq('Update user in deputy - Success')
        end

        it 'should not update user in Deputy if data is not valid' do
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee/#{update_user.deputy_id}").
            to_return(status: 200, body: JSON.generate({'Id': 456}))
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@update_action, ['first name'])
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(200)
          expect(logging.action).to eq('Update user in deputy - Failure')
        end

        it 'should not update user in Deputy if data is not valid' do
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee/#{update_user.deputy_id}").
            to_return(status: 400, body: JSON.generate({'Id': 123}))
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@update_action, ['first name'])
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(400)
          expect(logging.action).to eq('Update user in deputy - Failure')
        end

        it 'should not update user in Deputy if there is some excpetion during making request' do
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@update_action, ['first name'])
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(500)
          expect(logging.action).to eq('Update user in deputy - Failure')
        end
      end

      context 'update Profile In Deputy with out custom table' do
        it 'should update user in Deputy with out custom table' do
          FactoryGirl.create(:currency_field_with_value, user: update_user_2.reload, company: company3)
          stub_request(:post, "https://#{deputy3.subdomain}/api/v1/supervise/employee/#{update_user_2.deputy_id}").
            to_return(status: 200, body: JSON.generate({'Id': 123}))
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user_2).perform(@update_action, ['first name', 'home address'])
          logging = company3.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(200)
          expect(logging.action).to eq('Update user in deputy - Success')
        end

      end
      
      context 'Delete Sapling Profile In Deputy' do
        it 'should delete user in Deputy' do
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee/#{update_user.deputy_id}/delete").
            to_return(status: 200, body: '')
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@delete_action)
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(200)
          expect(update_user.reload.deputy_id).to eq(nil)
            expect(logging.action).to eq('Delete user in deputy - Success')
        end
        
        it 'should not delete user in Deputy if Deputy id is invalid' do
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee/#{update_user.deputy_id}/delete").
            to_return(status: 404, body: JSON.generate({'Id': 123}))
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@delete_action)
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(update_user.reload.deputy_id).not_to eq(nil)

          expect(logging.state).to eq(404)
          expect(logging.action).to eq('Delete user in deputy - Failure')
        end

        it 'should not delete user in Deputy there is some excpetion while deleting' do
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@delete_action)
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(500)
          expect(logging.action).to eq('Delete user in deputy - Failure')
        end
      end

      context 'Terminate Sapling Profile In Deputy' do
        it 'should delete user in Deputy' do
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee/#{update_user.deputy_id}/terminate").
            to_return(status: 200, body: JSON.generate({'Id': 123}))
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@terminate_action)
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(200)
          expect(logging.action).to eq('Terminate user in deputy - Success')
        end
        
        it 'should not delete user in Deputy if Deputy id is invalid' do
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee/#{update_user.deputy_id}/terminate").
            to_return(status: 404, body: JSON.generate({'Id': 123}))
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@terminate_action)
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(404)
          expect(logging.action).to eq('Terminate user in deputy - Failure')
        end

        it 'should not delete user in Deputy there is some excpetion while deleting' do
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@terminate_action)
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(500)
          expect(logging.action).to eq('Terminate user in deputy - Failure')
        end
      end

      context 'Rehire Sapling Profile In Deputy' do
        it 'should rehire user in Deputy' do
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee/#{update_user.deputy_id}/activate").
            to_return(status: 200, body: JSON.generate({'Id': 123}))
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@rehire_action)
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(200)
          expect(logging.action).to eq('Rehire/Activate user in deputy - Success')
        end
        
        it 'should not rehire user in Deputy if Deputy id is invalid' do
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee/#{update_user.deputy_id}/activate").
            to_return(status: 404, body: JSON.generate({'Id': 123}))
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@rehire_action)
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(404)
          expect(logging.action).to eq('Rehire/Activate user in deputy - Failure')
        end

        it 'should not rehire user in Deputy there is some excpetion while deleting' do
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@rehire_action)
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(500)
          expect(logging.action).to eq('Rehire/Activate user in deputy - Failure')
        end
      end

      context 'Rehire and Update Sapling Profile In Deputy' do
        before(:each) do
          allow_any_instance_of(IntegrationInstance).to receive(:can_invite_profile).and_return(true)
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee/#{update_user.deputy_id}/activate").
            to_return(status: 200, body: JSON.generate({'Id': 123}))
        end
        it 'should update user in Deputy' do
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee/#{update_user.deputy_id}").
            to_return(status: 200, body: JSON.generate({'Id': 123}))
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@rehire_and_update)
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(200)
          expect(logging.action).to eq('Updated Rehired/Activated user in deputy - Success')
        end

        it 'should not update user in Deputy if data is not valid' do
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee/#{update_user.deputy_id}").
            to_return(status: 200, body: JSON.generate({'Id': 456}))
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@rehire_and_update)
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(200)
          expect(logging.action).to eq('Updated Rehired/Activated user in deputy - Failure')
        end

        it 'should not update user in Deputy if data is not valid' do
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee/#{update_user.deputy_id}").
            to_return(status: 400, body: JSON.generate({'Id': 123}))
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@rehire_and_update)
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(400)
          expect(logging.action).to eq('Updated Rehired/Activated user in deputy - Failure')
        end

        it 'should not update user in Deputy if there is some excpetion during making request' do
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@rehire_and_update)
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(500)
          expect(logging.action).to eq('Updated Rehired/Activated user in deputy - Failure')
        end
      end

      context 'Terminate and delete Sapling Profile In Deputy' do
        it 'should terminate and delete user in Deputy' do
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee/#{update_user.deputy_id}/terminate").
            to_return(status: 200, body: JSON.generate({'Id': 123}))
          stub_request(:post, "https://#{deputy.subdomain}/api/v1/supervise/employee/#{update_user.deputy_id}/delete").
            to_return(status: 200, body: '')
          ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(update_user).perform(@terminate_and_delete)
          logging = company.loggings.where(integration_name: 'Deputy').last
          expect(logging.state).to eq(200)
          expect(logging.action).to eq('Delete user in deputy - Success')
        end
      end

    end
  end
end