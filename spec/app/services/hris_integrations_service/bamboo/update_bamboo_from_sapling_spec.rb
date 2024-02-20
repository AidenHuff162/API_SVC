require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe HrisIntegrationsService::Bamboo::UpdateBambooFromSapling do

  let!(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, bamboo_id: 'id', company: company, profile_image: create(:profile_image, :for_nick)) }
  let!(:integration) {create(:bamboohr_integration, company: company)}

  before(:each) do
    WebMock.disable_net_connect!
    allow_any_instance_of(Company).to receive(:integration_types) { ['bamboo_hr']}
    allow_any_instance_of(RestClient::Request).to receive(:execute) { true} 
    MiniMagick::Image.stub(:open) { double('file', path: 'path')}
    allow_any_instance_of(Bamboozled::API::Employee).to receive(:update) { true }
    allow_any_instance_of(Bamboozled::API::Employee).to receive(:add) { JSON.parse({'headers': {'location': 'a/0'}}.to_json) }

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/emergencyContacts").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/jobInfo").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/employmentStatus").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customLevel").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customImmigration").
      to_return(status: 201, body: {}.to_json)
    
    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customBonus").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/compensation").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customBonuses").
      to_return(status: 201, body: {}.to_json)
    
    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customDirectDeposit").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customFederalTaxWithholding").
      to_return(status: 201, body: {}.to_json)
  
    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/commission").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customEquity").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customJobFamily1").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customReqID").
      to_return(status: 201, body: {}.to_json)
    
    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customPhysicalOfficeLocation1").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customNewHireGrants").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customSecondaryCompensation").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customStockAwards").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customStockAwards").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customVisaInformation").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customCommissionPlan").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customCommissionPlan").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customBonusPayments").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customLevel1").
      to_return(status: 201, body: {}.to_json)

    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customBonusPlan").
      to_return(status: 201, body: {}.to_json)
      
    stub_request(:post, "https://api.bamboohr.com/api/gateway.php/sapling-sandbox/v1/employees/#{user.bamboo_id}/tables/customBonusPlan").
      to_return(status: 201, body: {}.to_json)
          
  end

  describe '#update bamboo from sapling' do
    context 'Profile Picture' do
      it 'should update Profile picture from sapling' do
        File.stub(:new) { true}
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(user, false).update('Profile Photo')
        expect(company.loggings.last.action.include?('Update Profile Photo In Bamboo (0) - Success')).to eq (true)
      end

      it 'should not update Profile picture from sapling' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(user, false).update('Profile Photo')
        expect(company.loggings.last.action.include?('Update Profile Photo In Bamboo (0) - Failure')).to eq (true)
      end
    end

    context 'updating user fields' do
      it 'should update Emergency Contect from sapling' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(user, false).update('emergency contact name')
        expect(company.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should update Job information from sapling' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(user, false).update('division')
        expect(company.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should update Employment status from sapling' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(user, false).update('employment status')
        expect(company.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should update Date of Birth from sapling' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(user, false).update('date of birth')
        expect(company.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should update first_name from sapling' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(user, false).update('first_name')
        expect(company.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end
    end
  end

  describe '#create bamboo from sapling' do
    before {File.stub(:new) { true} }
    context 'Create Profile' do
      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(user, false).create(false)
        expect(company.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end
    end

    context 'Addepar' do
      let(:company1) {create(:addepar_company)}
      let(:nick) {create(:nick, bamboo_id: 'id', company: company1)}
      let!(:integration) {create(:bamboohr_integration, company: company1)}
      let!(:custom_field) {create(:custom_field, company: company1, name: 'level', field_type: 6)}
      let!(:custom_field_value) {create(:custom_field_value, custom_field: custom_field, user: nick, value_text: Date.today.to_s)}
      let!(:custom_field1) {create(:custom_field, company: company1, name: 'country of citizenship', field_type: 0)}
      let!(:custom_field_value1) {create(:custom_field_value, custom_field: custom_field1, user: nick, value_text: Date.today.to_s)}
      let!(:custom_field2) {create(:custom_field, company: company1, name: 'bonus amount', field_type: 0)}
      let!(:custom_field_value2) {create(:custom_field_value, custom_field: custom_field2, user: nick, value_text: Date.today.to_s)}
      let!(:custom_field3) {create(:custom_field, company: company1, name: 'pay rate', field_type: 0)}
      let!(:custom_field_value3) {create(:custom_field_value, custom_field: custom_field3, user: nick, value_text: Date.today.to_s)}

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).create(false)
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should update user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('emergency contact address')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should update user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('level')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should update user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('country of citizenship')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should update user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('bonus amount')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should update user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('pay rate')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end
    end

    context 'Scality' do
      let(:company1) {create(:scality_company)}
      let(:nick) {create(:nick, bamboo_id: 'id', company: company1)}
      let!(:integration) {create(:bamboohr_integration, company: company1)}

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).create(false)
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end
    end

    context 'Fivestars' do
      let(:company1) {create(:five_company)}
      let(:nick) {create(:nick, bamboo_id: 'id', company: company1)}
      let!(:integration) {create(:bamboohr_integration, company: company1)}
      let!(:custom_field) {create(:custom_field, company: company1, name: 'pay type', field_type: 0)}
      let!(:custom_field_value) {create(:custom_field_value, custom_field: custom_field, user: nick, value_text: Date.today.to_s)}
      let!(:custom_field1) {create(:custom_field, company: company1, name: 'work state', field_type: 0)}
      let!(:custom_field_value1) {create(:custom_field_value, custom_field: custom_field1, user: nick, value_text: Date.today.to_s)}
      let!(:custom_field2) {create(:custom_field, company: company1, name: 'direct deposit: bank type', field_type: 0)}
      let!(:custom_field_value2) {create(:custom_field_value, custom_field: custom_field2, user: nick, value_text: Date.today.to_s)}

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).create(false)
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('emergency contact address')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('pay type')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('benefits eligible')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('work state')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('direct deposit: bank type')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end
    end

    context 'Doordash' do
      let(:company1) {create(:door_company)}
      let(:nick) {create(:nick, bamboo_id: 'id', company: company1)}
      let!(:integration) {create(:bamboohr_integration, company: company1)}
      let!(:custom_field) {create(:custom_field, company: company1, name: 'sign on bonus', field_type: 0)}
      let!(:custom_field_value) {create(:custom_field_value, custom_field: custom_field, user: nick, value_text: Date.today.to_s)}
      let!(:custom_field1) {create(:custom_field, company: company1, name: 'pay type', field_type: 0)}
      let!(:custom_field_value1) {create(:custom_field_value, custom_field: custom_field1, user: nick, value_text: Date.today.to_s)}
      let!(:custom_field2) {create(:custom_field, company: company1, name: 'commission amount', field_type: 0)}
      let!(:custom_field_value2) {create(:custom_field_value, custom_field: custom_field2, user: nick, value_text: Date.today.to_s)}
      let!(:custom_field3) {create(:custom_field, company: company1, name: 'physical work location', field_type: 0)}
      let!(:custom_field_value3) {create(:custom_field_value, custom_field: custom_field3, user: nick, value_text: Date.today.to_s)}
      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).create(false)
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('marital status')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('sign on bonus')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('pay type')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('commission amount')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end
    end

    context 'DigitalOcean' do
      let(:company1) {create(:digital_company)}
      let(:nick) {create(:nick, bamboo_id: 'id', company: company1)}
      let!(:integration) {create(:bamboohr_integration, company: company1)}
      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).create(false)
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('first_name')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end
    end

    context 'Forward' do
      let(:company1) {create(:forward_company)}
      let(:nick) {create(:nick, bamboo_id: 'id', company: company1)}
      let!(:integration) {create(:bamboohr_integration, company: company1)}
      let!(:custom_field) {create(:custom_field, company: company1, name: 'pay type', field_type: 0)}
      let!(:custom_field_value) {create(:custom_field_value, custom_field: custom_field, user: nick, value_text: Date.today.to_s)}
      let!(:custom_field1) {create(:custom_field, company: company1, name: 'secondary compensation - pay rate', field_type: 0)}
      let!(:custom_field_value1) {create(:custom_field_value, custom_field: custom_field1, user: nick, value_text: Date.today.to_s)}
      let!(:custom_field2) {create(:custom_field, company: company1, name: 'vest terms', field_type: 0)}
      let!(:custom_field_value2) {create(:custom_field_value, custom_field: custom_field2, user: nick, value_text: Date.today.to_s)}
      let!(:custom_field3) {create(:custom_field, company: company1, name: 'visa expiration', field_type: 0)}
      let!(:custom_field_value3) {create(:custom_field_value, custom_field: custom_field3, user: nick, value_text: Date.today.to_s)}
      let!(:custom_field4) {create(:custom_field, company: company1, name: 'target', field_type: 0)}
      let!(:custom_field_value4) {create(:custom_field_value, custom_field: custom_field4, user: nick, value_text: Date.today.to_s)}
      let!(:custom_field5) {create(:custom_field, company: company1, name: 'bonus payments - commission plan id', field_type: 0)}
      let!(:custom_field_value5) {create(:custom_field_value, custom_field: custom_field5, user: nick, value_text: Date.today.to_s)}
      let!(:custom_field6) {create(:custom_field, company: company1, name: 'level', field_type: 0)}
      let!(:custom_field_value6) {create(:custom_field_value, custom_field: custom_field6, user: nick, value_text: Date.today.to_s)}
      let!(:custom_field7) {create(:custom_field, company: company1, name: 'bonus plan - entity', field_type: 0)}
      let!(:custom_field_value7) {create(:custom_field_value, custom_field: custom_field7, user: nick, value_text: Date.today.to_s)}

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).create(false)
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('pay type')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('secondary compensation - pay rate')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('vest terms')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('visa expiration')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('target')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('bonus payments - commission plan id')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('level')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('bonus plan - entity')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end
    end

    context 'Zapier' do
      let(:company1) {create(:zapier_company)}
      let(:nick) {create(:nick, bamboo_id: 'id', company: company1)}
      let!(:custom_field) {create(:custom_field, company: company1, name: 'pay type', field_type: 0)}
      let!(:custom_field_value) {create(:custom_field_value, custom_field: custom_field, user: nick, value_text: Date.today.to_s)}
      let!(:integration) {create(:bamboohr_integration, company: company1)}

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).create(false)
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end

      it 'should create user in bamboo' do
        HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(nick, false).update('pay type')
        expect(company1.loggings.last.action.include?('In Bamboo (0) - Success')).to eq (true)
      end
    end
  end
end
