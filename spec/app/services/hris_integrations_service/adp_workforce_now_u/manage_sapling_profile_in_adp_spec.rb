require 'rails_helper'

RSpec.describe HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp do
  let(:company) { create(:company, subdomain: 'adp-company') }
  let(:location) { create(:location, company: company) }
  let!(:adp_us) { create(:adp_wfn_us_integration, company: company, filters: {location_id: [location.id], team_id: ['all'], employee_type: ['all'] }) }
  let(:user) {create(:user, state: :active, current_stage: :registered, company: company, location: location, adp_wfn_us_id: '123') }
  let(:user1) { create(:user, state: :active, current_stage: :registered, company: company, location: location) } 
  
  let(:company2) { create(:company, subdomain: 'adp-company-2') }
  let!(:adp_can) { create(:adp_wfn_can_integration, company: company2, filters: {location_id: ['all'], team_id: ['all'], employee_type: ['all']}) }
  let(:user2) { create(:user, state: :active, current_stage: :registered, company: company2) } 

  before(:all) do
    WebMock.disable_net_connect!
  end

  describe '#create' do
    context 'credentials are valid' do
      before(:each) do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_return('token')
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_certificate).and_return(OpenStruct.new({cert: 'cert', key: 'key'}))
      end
      
      it 'should create user for ADP US' do
        response = double('body', :body => JSON.generate({'events'=>[{'data'=>{'output'=>{'applicant'=>{'associateOID'=>'123'}}}}]}), :reason_phrase => 'Created', :status => 201)
        
        data = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new('US').build_applicant_onboard_data(user1, adp_us)
        params = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new.build_applicant_onboard_params(data)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:post).and_return(response)

        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user1).create
        expect(user1.adp_wfn_us_id).to eq('123')
      end

      it 'should create user for ADP CAN' do
        response = double('body', :body => JSON.generate({'events'=>[{'data'=>{'output'=>{'applicant'=>{'associateOID'=>'123'}}}}]}), :reason_phrase => 'Created', :status => 201)
    
        FactoryGirl.create(:sin_field_with_value, user: user2, company: company2)
        data = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new('CAN').build_applicant_onboard_data(user2, adp_can)
        params = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new.build_applicant_onboard_params(data)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:post).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user2).create
        expect(user2.adp_wfn_can_id).to eq('123')
      end

      it 'should return Create Profile in ADP - ERROR if ADP ID is not present' do
        response = double('body', :body => JSON.generate({'events'=>[{'data'=>{'output'=>{'applicant'=>''}}}]}), :reason_phrase => 'Created', :status => 201)
        data = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new('CAN').build_applicant_onboard_data(user2, adp_can)
        params = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new.build_applicant_onboard_params(data)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:post).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user2).create
        logging = company2.loggings.where(integration_name: 'ADP Workforce Now - CAN').last
        expect(logging.state).to eq(201)
        expect(logging.action).to eq('Create Profile in ADP V1 - ERROR')
      end

      it 'should return 400 error if data is invalid' do
        response = double('body', :body => JSON.generate({'events'=>[{'data'=>{'output'=>{'applicant'=>{'associateOID'=>'123'}}}}]}), :reason_phrase => '', :status => 400)
        data = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new('CAN').build_applicant_onboard_data(user2, adp_can)
        params = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new.build_applicant_onboard_params(data)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:post).and_return(response)

        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user2).create
        logging = company2.loggings.where(integration_name: 'ADP Workforce Now - CAN').last
        expect(logging.state).to eq(400)
        expect(logging.action).to eq('Create Profile in ADP V1 - ERROR')
      end

      it 'should return 500 error if there is some exception' do
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user1).create
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Create Profile in ADP V1 - ERROR')
      end
    end
  end

  describe '#update' do
    context 'credentials are invalid' do
      it 'should return 500 if access token is invalid' do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_raise(Exception)
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('email', 'test@test.com')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in ADP - Access Token Retrieval - ERROR')
      end

      it 'should return 500 if certificate is invalid' do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_return('token')
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_certificate).and_raise(Exception)
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('email', 'test@test.com')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in ADP - Certificate Retrieval - ERROR')
      end
    end

    context 'credentials are valid' do
       before(:each) do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_return('token')
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_certificate).and_return(OpenStruct.new({cert: 'cert', key: 'key'}))
      end
      
      it 'should update email in ADP' do
        response = double('body', :body => JSON.generate({'events'=>[{'data'=>{'output'=>{'applicant'=>{'associateOID'=>'123'}}}}]}), :reason_phrase => '', :status => 200)
        data = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new('US').build_change_business_communication_email_data('test@test.com', user)
        params = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new.build_change_business_communication_email_params(data)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:post).and_return(response)
       
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('email', 'test@test.com')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in ADP - Email')
      end

      it 'should not update email in there is some error error in request' do
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('email', 'test@test.com')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in ADP - Email - ERROR')
      end

      it 'should update personal email in ADP' do
        response = double('body', :body => JSON.generate({'events'=>[{'data'=>{'output'=>{'applicant'=>{'associateOID'=>'123'}}}}]}), :reason_phrase => '', :status => 200)
        data = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new('US').build_change_personal_communication_email_data('test@test.com', user)
        params = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new.build_change_personal_communication_email_params(data)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:post).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('personal email', 'test@test.com')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in ADP - Personal Email')
      end

      it 'should not update peronsal email in there is some error error in request' do
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('personal email', 'test@test.com')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in ADP - Personal Email - ERROR')
      end


      it 'should update preferred name in ADP' do
        response = double('body', :body => JSON.generate({'events'=>[{'data'=>{'output'=>{'applicant'=>{'associateOID'=>'123'}}}}]}), :reason_phrase => '', :status => 200)
        data = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new('US').build_change_preferred_name_data('preferred name', user)
        params = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new.build_change_preferred_name_params(data)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:post).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('preferred name', 'preferred name')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in ADP - Preferred Name')
      end

      it 'should update middle name in ADP' do
        response = double('body', :body => JSON.generate({'events'=>[{'data'=>{'output'=>{'applicant'=>{'associateOID'=>'123'}}}}]}), :reason_phrase => '', :status => 200)
        data = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new('US').build_change_middle_name_data('middle name', user)
        params = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new.build_change_middle_name_params(data)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:post).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('middle name', 'middle name')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in ADP - Middle Name')
      end

      it 'should not update preferred name in there is some error error in request' do
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('preferred name', 'preferred name')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in ADP - Preferred Name - ERROR')
      end

      it 'should update federal marital status in ADP' do
        response = double('body', :body => JSON.generate({'events'=>[{'data'=>{'output'=>{'applicant'=>{'associateOID'=>'123'}}}}]}), :reason_phrase => '', :status => 200)
        data = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new('US').build_change_marital_status_data(user)
        params = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new.build_change_marital_status_params(data)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:post).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('federal marital status', 'federal marital status')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in ADP - Marital Status')
      end

      it 'should not update federal marital status in there is some error error in request' do
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('federal marital status', 'federal marital status')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in ADP - Marital Status - ERROR')
      end


      it 'should update home address in ADP' do
        response = double('body', :body => JSON.generate({'events'=>[{'data'=>{'output'=>{'applicant'=>{'associateOID'=>'123'}}}}]}), :reason_phrase => '', :status => 200)
        data = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new('US').build_change_legal_address_data(user)
        params = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new.build_change_legal_address_params(data)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:post).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('home address', 'home address')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in ADP - Home Address')
      end

      it 'should not update home address in there is some error error in request' do
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('home address', 'home address')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in ADP - Home Address - ERROR')
      end

      it 'should update home phone number in ADP' do
        response = double('body', :body => JSON.generate({'events'=>[{'data'=>{'output'=>{'applicant'=>{'associateOID'=>'123'}}}}]}), :reason_phrase => '', :status => 200)
        data = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new('US').build_change_personal_communication_landline_data(user)
        params = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new.build_change_personal_communication_landline_params(data)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:post).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('home phone number', 'home phone number')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in ADP - Home Phone')
      end

      it 'should not update home phone number in there is some error error in request' do
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('home phone number', 'home phone number')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in ADP - Home Phone - ERROR')
      end

      it 'should update mobile phone number in ADP' do
        response = double('body', :body => JSON.generate({'events'=>[{'data'=>{'output'=>{'applicant'=>{'associateOID'=>'123'}}}}]}), :reason_phrase => '', :status => 200)
        data = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new('US').build_change_personal_communication_mobile_data(user)
        params = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new.build_change_personal_communication_mobile_params(data)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:post).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('mobile phone number', 'mobile phone number')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in ADP - Mobile Phone')
      end

      it 'should not update mobile phone number in there is some error error in request' do
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('mobile phone number', 'mobile phone number')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in ADP - Mobile Phone - ERROR')
      end

      it 'should update pay rate in ADP' do
        FactoryGirl.create(:currency_field_with_value, user: user, company: company)
        FactoryGirl.create(:adp_rate_type_with_value, user: user, company: company)
        response = double('body', :body => JSON.generate({'events'=>[{'data'=>{'output'=>{'applicant'=>{'associateOID'=>'123'}}}}]}), :reason_phrase => '', :status => 200)
        data = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new('US').build_change_base_remunration_data(user)
        params = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new.build_change_base_remunration_params(data)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:post).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('pay rate', 'pay rate')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in ADP - Payroll Information')
      end

      it 'should not update pay rate in there is some error error in request' do
        FactoryGirl.create(:currency_field_with_value, user: user, company: company)
        FactoryGirl.create(:adp_rate_type_with_value, user: user, company: company)
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('pay rate', 'pay rate')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in ADP - Payroll Information - ERROR')
      end

      it 'should update race/ethnicity in ADP' do
        company.custom_fields.where(name: 'Race/Ethnicity').take.destroy
        FactoryGirl.create(:adp_race_ethnicity, user: user, company: company)
        response = double('body', :body => JSON.generate({'events'=>[{'data'=>{'output'=>{'applicant'=>{'associateOID'=>'123'}}}}]}), :reason_phrase => '', :status => 200)
        data = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new('US').build_change_ethnicity_data(user)
        params = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new.build_change_ethnicity_params(data)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:post).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('race/ethnicity', 'race/ethnicity')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in ADP - Race/Ethnicity - SUCCESS')
      end

      it 'should not update race/ethnicity in there is some error error in request' do
        company.custom_fields.where(name: 'Race/Ethnicity').take.destroy
        FactoryGirl.create(:adp_race_ethnicity, user: user, company: company)
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('race/ethnicity', 'race/ethnicity')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in ADP - Race/Ethnicity - ERROR')
      end      

      it 'should terminate employee in ADP' do
        response = double('body', :body => JSON.generate({'events'=>[{'data'=>{'output'=>{'applicant'=>{'associateOID'=>'123'}}}}]}), :reason_phrase => 'OK', :status => 200)
        data = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new('US').build_terminate_employee_data(user)
        params = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new.build_terminate_employee_params('123', data)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:post).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('Termination Date', {termination_date: Date.today.strftime('%Y-%m-%d'), last_day_worked: Date.today.strftime('%Y-%m-%d') }.to_json)
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Terminate employee in ADP - SUCCESS')
      end

      it 'should not Terminate employee in ADP, there is some error in request' do
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('Termination Date', {termination_date: Date.today.strftime('%Y-%m-%d'), last_day_worked: Date.today.strftime('%Y-%m-%d') }.to_json)
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Terminate employee in ADP - ERROR')
      end  

      it 'should rehire employee in ADP' do
        response = double('body', :body => JSON.generate({'workers'=>[{'workAssignments'=>[{'primaryIndicator'=>true,'positionID'=>'123'}]}]}), :reason_phrase => 'OK', :status => 200)
        response1 = double('body', :body => JSON.generate({'events'=>[{'data'=>{'output'=>{'applicant'=>{'associateOID'=>'123'}}}}]}), :reason_phrase => 'OK', :status => 200)
        data = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new('US').build_rehire_employee_data(user, '123')
        params = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new.build_rehire_employee_params(data)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:get).and_return(response)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:post).and_return(response1)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('is rehired', 'is rehired')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('ReHire employee in ADP - SUCCESS')
      end

      it 'should not rehire employee in ADP, there is some error in request' do
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update('is rehired', 'is rehired')
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
      end
    end
  end
end