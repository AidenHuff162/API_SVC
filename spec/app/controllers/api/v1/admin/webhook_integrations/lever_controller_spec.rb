require 'rails_helper'

RSpec.describe Api::V1::Admin::WebhookIntegrations::LeverController, type: :controller do
  let(:company) { create(:company, subdomain: 'lever') }
  let(:lever_integration_inventory) {create(:integration_inventory, display_name: 'Lever', status: 2, category: 0, data_direction: 1, enable_filters: false, api_identifier: 'lever', field_mapping_option: 'integration_fields', field_mapping_direction: 'integration_mapping')}
  let(:lever_integration_instance) {create(:integration_instance, api_identifier: 'lever', state: 'active', integration_inventory_id: lever_integration_inventory.id, name: 'Instance no.1', company_id: company.id)}

  before do
    allow(controller).to receive(:current_company).and_return(company)
    @params = {data: {opportunityId: '12345'}, token: 'token', triggeredAt: 'triggeredAt', signature: 'signature' }
    @candidate_data = { 'name' => 'Unit Test', 'location' => 'USA', 'emails' => ['unit@test.com'], 'archived' => {'archivedAt' => 1562860495318}, 'sources' => ['xyzsource'], 'sources' => ['xyzsource'] }
    @hired_candidate_profile_form_fields = [ {'text' => 'start date', 'value' => 1562860495618}, {'text' => 'location', 'value' => 'London'} ]
    @offer_data = {'fields' => [{'identifier' => 'anticipated_start_date', 'value' => 1562860497318}, {'identifier' => 'team', 'value' => 'Sales'}, {'identifier' => 'salary_amount', 'value' => 2300},
          {'identifier' => 'location', 'value' => 'New York'}, {'identifier' => 'custom', 'value' => 'custom_field'}]}
    @candidate_posting_data = {'text' => 'Unit tester', 'categories' => {'team' => 'Marketing', 'location' => 'Turkey', 'commitment' => 'Full Time'}}
    @hired_candidate_requisition_posting_data = {'customFields' => [{'identifier' => 'name', 'value' => 'Unit Test'}, {'identifier' => 'requisitionCode', 'value' => 1562860497318}, {'identifier' => 'internalNotes', 'value' => 'abc'}, {'identifier' => 'location', 'value' => 'New York'}]}
    @referral_data = {'text'=>'Referrer', 'identifier'=>'referrals', 'value'=>'Ali ahmad'}
    @application = {"manager_id"=>"b55a3ee6-0b88-4767-ade7-ee58c08370d8", "posting"=>"e971b9ab-177b-4619-98d9-87cef6e1c16e", "requisition_id"=>"fb4112cc-dfb6-41e2-a159-bdca0d05ca5d"}
  end

  describe 'post #create' do
    context 'It should create pending Hire according to new architecture' do
      it 'should create pending hire' do
        allow(controller).to receive(:current_company).and_return(company)
        allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })
        company.stub(:lever_mapping_feature_flag) { true }
        lever_integration_instance.stub(:api_key) { '1233api_key' }
        lever_integration_instance.stub(:signature_token) { 'signature' }
        allow_any_instance_of(AtsIntegrationsService::Lever::Helper).to receive(:verify_lever_webhook?).and_return(true)
        allow_any_instance_of(AtsIntegrationsService::Lever::ManageLeverProfileInSapling).to receive(:fetch_lever_sections_data) { 'Data Fetched and saved' }
        post :create, params: @params, format: :json

        expect(response.status).to eq(200)
      end

      it 'should return pending hire params according to field mappings' do
        FactoryGirl.create(:integration_field_mapping, integration_field_key: 'manager_id', custom_field_id: nil, preference_field_id: 'null', is_custom: false, parent_hash: nil, parent_hash_path: nil, integration_instance_id: lever_integration_instance.id, company_id: company.id, integration_selected_option: {id: "manager_offer_data", name: "Hiring Manager (Offer Form)", section: "offer_data"})
        FactoryGirl.create(:integration_field_mapping, integration_field_key: 'location_id', custom_field_id: nil, preference_field_id: 'null', is_custom: false, parent_hash: nil, parent_hash_path: nil, integration_instance_id: lever_integration_instance.id, company_id: company.id, integration_selected_option: {id: "location_candidate_data", name: "Location (Candidate)", section: "candidate_data"})
        FactoryGirl.create(:integration_field_mapping, integration_field_key: 'team_id', custom_field_id: nil, preference_field_id: 'null', is_custom: false, parent_hash: nil, parent_hash_path: nil, integration_instance_id: lever_integration_instance.id, company_id: company.id, integration_selected_option: {id: "location_hired_candidate_form_fields", name: "Location (Form Fields)", section: "hired_candidate_form_fields"})
        FactoryGirl.create(:integration_field_mapping, integration_field_key: 'title', custom_field_id: nil, preference_field_id: 'null', is_custom: false, parent_hash: nil, parent_hash_path: nil, integration_instance_id: lever_integration_instance.id, company_id: company.id, integration_selected_option: {id: "job_title_candidate_posting_data", name: "Title (Job Posting)", section: "candidate_posting_data"})
        FactoryGirl.create(:integration_field_mapping, integration_field_key: 'start_date', custom_field_id: nil, preference_field_id: 'null', is_custom: false, parent_hash: nil, parent_hash_path: nil, integration_instance_id: lever_integration_instance.id, company_id: company.id, integration_selected_option: {id: "start_date_candidate_data", name: "Archived At (Candidate)", section: "candidate_data"})

        allow(controller).to receive(:current_company).and_return(company)
        allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })
        company.stub(:lever_mapping_feature_flag) { true }
        lever_integration_instance.stub(:api_key) { '1233api_key' }
        lever_integration_instance.stub(:signature_token) { 'signature' }
        allow_any_instance_of(AtsIntegrationsService::Lever::Helper).to receive(:verify_lever_webhook?).and_return(true)
        allow_any_instance_of(AtsIntegrationsService::Lever::CandidateDataBuilder).to receive(:get_candidate_data).and_return({first_name: 'abc', last_name: 'xyz', personal_email: 'abc@gmail.com', phone_number: '123456789', start_date: '1-1-2021', location_id: nil})
        allow_any_instance_of(AtsIntegrationsService::Lever::ReferralDataBuilder).to receive(:get_referral_data).and_return(lever_custom_field: [{ "text" => "Referrer", "identifier" => "referrals", "value" => "abc" }])
        allow_any_instance_of(AtsIntegrationsService::Lever::ApplicationDataBuilder).to receive(:get_application_data).and_return({manager_id: 4, posting: 'a1b2c3', requisition_id: 'abcxyz-345'})
        allow_any_instance_of(AtsIntegrationsService::Lever::HiredCandidateFormFieldsDataBuilder).to receive(:get_hired_candidate_form_fields).and_return({start_date: '1-1-2021', location_id: 3})
        allow_any_instance_of(AtsIntegrationsService::Lever::OfferDataBuilder).to receive(:get_offer_data).and_return({start_date: '1-1-2021', team_id: 3, base_salary: 200, location_id: 4, employee_type: 'Full time', preferred_name: 'ab', title: 'SE', manager_id: 5})
        allow_any_instance_of(AtsIntegrationsService::Lever::CandidatePostingDataBuilder).to receive(:get_candidate_posting_data).and_return({team_id: 3, location_id: 4, employee_type: 'Full time', title: 'SE', manager_id: 5})
        allow_any_instance_of(AtsIntegrationsService::Lever::HiredCandidateRequisitionDataBuilder).to receive(:get_hired_candidate_requisition_data).and_return({team_id: 3, location_id: 4, employee_type: 'Full time', title: 'SE', manager_id: 5})
        allow_any_instance_of(AtsIntegrationsService::Lever::Helper).to receive(:fetch_user_from_lever).and_return(5)
        post :create, params: @params, format: :json
        
        expect(response.status).to eq(200)
        expect(company.pending_hires.last.first_name).to eq('abc')
        expect(company.pending_hires.last.last_name).to eq('xyz')
        expect(company.pending_hires.last.personal_email).to eq('abc@gmail.com')
        expect(company.pending_hires.last.phone_number).to eq('123456789')
        expect(company.pending_hires.last.employee_type).to eq('Full time')
        expect(company.pending_hires.last.manager_id).to eq(5)
        expect(company.pending_hires.last.location_id).to eq(nil)
        expect(company.pending_hires.last.team_id).to eq(nil)
        expect(company.pending_hires.last.title).to eq("SE")
        expect(company.pending_hires.last.start_date).to eq("2021-01-01T00:00:00+00:00")
      end
    end

    context 'It should not create pending Hire' do
      it 'should return not found status If current company is not present' do
        post :create, params: {data: @opportunityId }, format: :json

        expect(response.status).to eq(404)
        expect(JSON.parse(response.body)['errors'][0]['title']).to eq('Not Found')
      end
      
      it 'should return ok status and create failed webhook If current company is present and integration is not present' do
        allow(controller).to receive(:current_company).and_return(company)
        allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })
        company.stub(:lever_mapping_feature_flag) { false }
        post :create, params: {data: @opportunityId }, format: :json

        expect(response.status).to eq(200)
      end

      it 'should return ok status If current company and integration is present but credentials are invalid' do
        allow(controller).to receive(:current_company).and_return(company)
        allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })
        company.stub(:lever_mapping_feature_flag) { false }
        
        integration = FactoryGirl.create(:lever_integration, company: company)
        post :create, params: @params, format: :json
        
        expect(response.status).to eq(200)
      end

       it 'should return ok status If current company and integration is present and api_key and credentials are valid' do
        allow(controller).to receive(:current_company).and_return(company)
        allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })
        company.stub(:lever_mapping_feature_flag) { false }
        
        integration = FactoryGirl.create(:lever_integration, company: company)
        allow(controller).to receive(:verify_webhook?).and_return(true)
        post :create, params: @params, format: :json

        expect(response.status).to eq(200)
      end
    end

    context 'It should create pending Hire' do
      it 'should return ok status and create success webhook' do        
        allow(controller).to receive(:current_company).and_return(company)
        allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })
        company.stub(:lever_mapping_feature_flag) { false }
        
        integration = FactoryGirl.create(:lever_integration, company: company)
        allow(controller).to receive(:verify_webhook?).and_return(true)
        allow(controller).to receive(:get_hired_candidate_application).and_return({posting: 'posting', postingHiringManager: 'postingHiringManager', requisition_id: 'requisition_id'})
        allow(controller).to receive(:get_hired_candidate_form_fields).and_return(@hired_candidate_profile_form_fields)
        allow(controller).to receive(:get_candidate_offer_data).and_return(@offer_data)

        allow(controller).to receive(:get_candidate_posting_data).and_return(@candidate_posting_data)
        allow(controller).to receive(:get_candidate_posting_manager).and_return(nil)

        allow(controller).to receive(:get_candidate_requisition).and_return(@hired_candidate_requisition_posting_data)


        expect_any_instance_of(RestClient::Resource).to receive(:get) { @candidate_data }

        post :create, params: @params, format: :json

        expect(response.status).to eq(200)
      end
    end
  end
end
 