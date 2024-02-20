require 'rails_helper'

RSpec.describe HrisIntegrationsService::Paychex::ManageSaplingProfileInPaychex do
  let(:company) { create(:company) }
  let(:company2) { create(:company) }
  let(:location) { create(:location, company: company) }
  let!(:paychex) { create(:paychex_integration, company: company, filters: {location_id: [location.id], team_id: ['all'], employee_type: ['all'] }) }
  let!(:invalid_paychex) { create(:paychex_integration, company: company2, filters: {location_id: [location.id], team_id: ['all'], employee_type: ['all'] }) }

  let(:user) { create(:user, state: :active, current_stage: :registered, company: company, location: location) } 
  let(:user2) { create(:user, state: :active, current_stage: :registered, company: company2, location: location) } 
  let(:update_user) { create(:user, state: :active, current_stage: :registered, company: company, location: location, paychex_id: '123') } 

  before(:all) do
    @create_action = 'create'
    @update_action = 'update'
    WebMock.disable_net_connect!
    parameter_mapping = ::HrisIntegrationsService::Paychex::ParamsMapper.new.build_parameter_mappings
    @data_builder = ::HrisIntegrationsService::Paychex::DataBuilder.new(parameter_mapping)
    @params_builder = ::HrisIntegrationsService::Paychex::ParamsBuilder.new(parameter_mapping)
  end

  before(:each) do
    allow_any_instance_of(IntegrationInstance).to receive(:access_token).and_return('1212abab')
    allow_any_instance_of(IntegrationInstance).to receive(:expires_in).and_return(Time.now.utc+55.minutes)
    allow_any_instance_of(IntegrationInstance).to receive(:subdomain).and_return('test')
    allow_any_instance_of(IntegrationInstance).to receive(:company_code).and_return('123')
  end

  describe '#perform' do
    context 'action is invalid' do
      it 'should return 404 if action is invalid' do
        ::HrisIntegrationsService::Paychex::ManageSaplingProfileInPaychex.new(user).perform(nil)
        logging = company.loggings.where(integration_name: 'Paychex').last
        expect(logging.state).to eq(404)
        expect(logging.action).to eq('Action missing')
      end
    end

    context 'integration is invalid' do
      before(:each) do
        allow_any_instance_of(IntegrationInstance).to receive(:access_token).and_return(nil)
        allow_any_instance_of(IntegrationInstance).to receive(:expires_in).and_return(nil)
        allow_any_instance_of(IntegrationInstance).to receive(:subdomain).and_return(nil)
        allow_any_instance_of(IntegrationInstance).to receive(:company_code).and_return(nil)
      end
      it 'should return 400 if access_token is invalid' do
        stub_request(:post, "https://api.paychex.com/auth/oauth/v2/token").
         with(
           headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Host'=>'api.paychex.com',
          'User-Agent'=>'Ruby'
           }).
         to_return(status: 401, body: "")

        ::HrisIntegrationsService::Paychex::ManageSaplingProfileInPaychex.new(user2).perform(@create_action)
        logging = company2.loggings.where(integration_name: 'Paychex').last
        expect(logging.state).to eq(401)
        expect(logging.action).to eq("Paychex access token generation failed - #{@create_action}")
      end

      it 'should return 404 if integration is invalid' do
        stub_request(:post, "https://api.paychex.com/auth/oauth/v2/token").
         with(
           headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Host'=>'api.paychex.com',
          'User-Agent'=>'Ruby'
           }).
         to_return(status: 200, body: JSON.generate({'expires_in'=>2}))
        ::HrisIntegrationsService::Paychex::ManageSaplingProfileInPaychex.new(user2).perform(@create_action)
        logging = company2.loggings.where(integration_name: 'Paychex').last
        expect(logging.state).to eq(404)
        expect(logging.action).to eq("Paychex credentials missing - #{@create_action}")
      end
    end

    context 'user is invalid' do
      it 'should reutn 404 if user is invalid' do
        user.update_column(:location_id, nil)
        ::HrisIntegrationsService::Paychex::ManageSaplingProfileInPaychex.new(user.reload).perform(@create_action)
        logging = company.loggings.where(integration_name: 'Paychex').last
        expect(logging.state).to eq(404)
        expect(logging.action).to eq("Paychex filters are not for user(#{user.id}) - #{@create_action}")
      end
    end

    context 'action is valid' do
      before(:each) do
        stub_request(:get, "https://api.paychex.com/companies/123/jobtitles").
         with(
           headers: {
          'Accept'=>'application/json',
          'Authorization'=>"Bearer #{paychex.access_token}"
          }).
         to_return(status: 200, body: JSON.generate({'content'=>['title'=>'test']}))

        stub_request(:get, "https://api.paychex.com/companies/123/locations").
         with(
           headers: {
          'Accept'=>'application/json',
          'Authorization'=>"Bearer #{paychex.access_token}"
           }).
         to_return(status: 200, body: "", headers: {})

      end

      context 'Create Sapling Profile In Paychex' do
        before(:each) do
          gender = company.custom_fields.find_by_name('Gender')
          FactoryGirl.create(:custom_field_value, custom_field: gender, user: user, custom_field_option_id: gender.custom_field_options.take.id)
          request_data = @data_builder.build_create_profile_data(user.reload)
          @request_params = @params_builder.build_create_profile_params(request_data)
          @response = JSON.generate({'content'=>['workerId'=>'456']})
        end

        it 'should create user in Paychex' do
          stub_request(:post, "https://api.paychex.com/companies/123/workers").
           with(
             body: JSON.generate(@request_params),
             headers: {
            'Accept'=>'*/*',
            'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Authorization'=>"Bearer #{paychex.access_token}",
            'Content-Type'=>'application/json',
            'Host'=>'api.paychex.com',
            'User-Agent'=>'Ruby'
             }).
            to_return(status: 201, body: @response)

          ::HrisIntegrationsService::Paychex::ManageSaplingProfileInPaychex.new(user).perform(@create_action)
          expect(user.reload.paychex_id).to eq('456')
        end

        it 'should not create user in Paychex if data is invalid' do
          stub_request(:post, "https://api.paychex.com/companies/123/workers").
           with(
             body: JSON.generate(@request_params),
             headers: {
            'Accept'=>'*/*',
            'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Authorization'=>"Bearer #{paychex.access_token}",
            'Content-Type'=>'application/json',
            'Host'=>'api.paychex.com',
            'User-Agent'=>'Ruby'
             }).
            to_return(status: 424, body: @response)
          ::HrisIntegrationsService::Paychex::ManageSaplingProfileInPaychex.new(user).perform(@create_action)
          expect(user.reload.paychex_id).to eq(nil)
        end

        it 'should reutrn 500 if there is some exception' do
          ::HrisIntegrationsService::Paychex::ManageSaplingProfileInPaychex.new(user).perform(@create_action)
          expect(user.reload.paychex_id).to eq(nil)
        end
      end

      context 'Update Sapling Profile In Paychex' do
        before(:each) do
          request_data = @data_builder.build_update_profile_data(update_user.reload, 'title')
          @request_params = @params_builder.build_update_profile_params(request_data)
          @response = JSON.generate({'content'=>['workerId'=>'456']})
        end

        it 'should update user in Paychex' do
          stub_request(:patch, "https://api.paychex.com/workers/123").
           with(
             body: JSON.generate(@request_params),
             headers: {
            'Accept'=>'application/json',
            'Authorization'=>"Bearer #{paychex.access_token}",
            'Content-Type'=>'application/json'
            }).
            to_return(status: 200, body: @response)
          ::HrisIntegrationsService::Paychex::ManageSaplingProfileInPaychex.new(update_user).perform(@update_action, 'title')
          logging = company.loggings.where(integration_name: 'Paychex').last
          expect(logging.state).to eq(200)
          expect(logging.action).to eq('Update user in Paychex - Success')
        end

        it 'should not update user in Paychex if data is invalid' do
         stub_request(:patch, "https://api.paychex.com/workers/123").
           with(
             body: JSON.generate(@request_params),
             headers: {
            'Accept'=>'application/json',
            'Authorization'=>"Bearer #{paychex.access_token}",
            'Content-Type'=>'application/json'
            }).
            to_return(status: 424, body: @response)
          ::HrisIntegrationsService::Paychex::ManageSaplingProfileInPaychex.new(update_user).perform(@update_action, 'title')
          logging = company.loggings.where(integration_name: 'Paychex').last
          expect(logging.state).to eq(424)
          expect(logging.action).to eq('Update user in Paychex - Failure')
        end

        it 'should reutrn 500 if there is some exception' do
          ::HrisIntegrationsService::Paychex::ManageSaplingProfileInPaychex.new(update_user).perform(@update_action, 'title')
          logging = company.loggings.where(integration_name: 'Paychex').last
          expect(logging.state).to eq(500)
          expect(logging.action).to eq('Update user in Paychex - Failure')
        end
      end
    end
  end
end  