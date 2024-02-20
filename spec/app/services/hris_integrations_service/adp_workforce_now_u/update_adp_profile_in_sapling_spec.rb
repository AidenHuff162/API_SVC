require 'rails_helper'

RSpec.describe HrisIntegrationsService::AdpWorkforceNowU::ManageAdpProfileInSapling do
  let(:company) { create(:company) }
  let(:adp_us) { create(:adp_wfn_us_integration, company: company, filters: {location_id: ['all'], team_id: ['all'], employee_type: ['all'] }) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company, adp_wfn_us_id: '123') } 

  let(:company2) { create(:company, is_using_custom_table: false) }
  let(:adp_can) { create(:adp_wfn_can_integration, company: company2, filters: {location_id: ['all'], team_id: ['all'], employee_type: ['all']}) }
  let(:user2) { create(:user, state: :active, current_stage: :registered, company: company2, adp_wfn_can_id: '123') } 

  let!(:api_logging) { create(:api_logging, api_key: 'ADP-US', company: company, status: 500, message: 'Invalid Request' ) }


  before(:all) do
    WebMock.disable_net_connect!
  end

  describe '#fetch_updates' do
    context 'credentails are invalid' do
      it 'should return 500 if access token is invalid' do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_raise(Exception)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Helper).to receive(:notify_slack).and_wrap_original { |m, *args| api_logging }
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateAdpProfileInSapling.new(adp_us).fetch_updates
        logging = company.api_loggings.where(api_key: 'ADP-US').last
        expect(logging.status).to eq('500')
        expect(logging.message).to eq('Invalid Request')
      end

      it 'should return 500 if Certificate is invalid' do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_return('token')
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_certificate).and_raise(Exception)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Helper).to receive(:notify_slack).and_wrap_original { |m, *args| api_logging }
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateAdpProfileInSapling.new(adp_us).fetch_updates
        logging = company.api_loggings.where(api_key: 'ADP-US').last
        expect(logging.status).to eq('500')
        expect(logging.message).to eq('Invalid Request')
      end
    end

    context 'credentails are valid' do
      before(:each) do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_return('token')
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_certificate).and_return(OpenStruct.new({cert: 'cert', key: 'key'}))
      end

      it 'should update adp profile in sapling with custom table' do
        user.reload
        response = double('body', :body => JSON.generate({'workers'=>[{'workerDates' => {'rehireDate'=> '2019-02-02'}, 'associateOID'=>'123','workAssignments'=>[{'hireDate'=> '2019-02-02', 'primaryIndicator'=>true, 'assignmentStatus'=>{'statusCode'=>{'codeValue'=>'A'}},'baseRemuneration'=>{'hourlyRateAmount'=>{'amountValue'=>'123','currencyCode'=>'code'}}, 'jobTitle'=>'Test'}], 'person'=>{'communication'=>{'emails'=>[{'emailUri'=>user.personal_email}]}}}]}), :reason_phrase => 'OK', :status => 200)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:fetch_worker).and_return(response)
        
        response = double('body', :body => JSON.generate({'a'=>'b'}), :reason_phrase => '', :status => 400)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:get).and_return(response)
        
        response = double('body', :body => '', :reason_phrase => '', :status => 200)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:delete).and_return(response)

        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateAdpProfileInSapling.new(adp_us).fetch_updates
        expect(user.reload.title).to eq('Test')
      end

      it 'should update adp profile in sapling with out custom table' do
        user2.reload
        response = double('body', :body => JSON.generate({'workers'=>[{'workerDates' => {'rehireDate'=> '2019-02-02'}, 'associateOID'=>'123','workAssignments'=>[{'hireDate'=> '2019-02-02', 'primaryIndicator'=>true, 'assignmentStatus'=>{'statusCode'=>{'codeValue'=>'A'}},'baseRemuneration'=>{'hourlyRateAmount'=>{'amountValue'=>'123','currencyCode'=>'code'}}, 'jobTitle'=>'Test'}], 'person'=>{'communication'=>{'emails'=>[{'emailUri'=>user.personal_email}]}}}]}), :reason_phrase => 'OK', :status => 200)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:fetch_worker).and_return(response)
        
        response = double('body', :body => JSON.generate({'a'=>'b'}), :reason_phrase => '', :status => 400)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:get).and_return(response)
        
        response = double('body', :body => '', :reason_phrase => '', :status => 200)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:delete).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateAdpProfileInSapling.new(adp_can).fetch_updates
        expect(user2.reload.title).to eq('Test')
      end
    end
  end
end 