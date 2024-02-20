require 'rails_helper'

RSpec.describe HrisIntegrationsService::Workday::Update::SaplingInWorkday do

  let(:company) { create(:company, subdomain: 'workday-company') }
  let(:workday_instance) { create(:workday_instance, company: company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company, workday_id: '1234', workday_id_type: 'Employee_ID') }
  let(:workday_federal_marital_status) { create(:workday_federal_marital_status, name: 'Workday Federal Marital Status', section: 'personal_info', field_type: 'mcq', company: company) }
  let(:workday_citizenship_country) { create(:workday_citizenship_country, name: 'Citizenship Country', section: 'personal_info', field_type: 'mcq', company: company) }
  let(:workday_citizenship_type) { create(:workday_citizenship_type, name: 'Citizenship Type', section: 'personal_info', field_type: 'mcq', company: company) }
  let(:workday_military_service) { create(:workday_military_service, name: 'Military Service', section: 'personal_info', field_type: 'mcq', company: company) }
  let(:workday_disability) { create(:workday_disability, name: 'Disability', section: 'personal_info', field_type: 'mcq', company: company) }
  let(:workday_ethnicity) { create(:workday_ethnicity, name: 'Workday Race/Ethnicity', section: 'personal_info', field_type: 'mcq', company: company) }
  let(:workday_gender) { create(:workday_gender, name: 'Workday Gender', section: 'personal_info', field_type: 'mcq', company: company) }
  let(:workday_emergency_contact_relationship) { create(:workday_emergency_contact_relationship, name: 'Workday Emergency Contact Relationship', section: 'personal_info', field_type: 'mcq', company: company) }
  let(:workday_termination_reason) { create(:workday_termination_reason, name: 'Workday Termination Reason', section: 'personal_info', field_type: 'mcq', company: company) }
  let(:attachment) {create(:document_upload_request_file)}
  let(:user_document_connection) { create(:user_document_connection, user: user, document_connection_relation: create(:document_connection_relation)) }

  subject(:update_sapling_in_workday) { ::HrisIntegrationsService::Workday::Update::SaplingInWorkday }
  subject(:workday_request_params_builder) { HrisIntegrationsService::Workday::ParamsBuilder::Workday }
  before(:example) { workday_instance.reload }

  describe '#manage mapping of sapling gender options to workday WIDs' do
    before(:each) do
      gender_fields = company.custom_fields.where(name: 'Gender')
      ProfileTemplateCustomFieldConnection.where(custom_field_id: gender_fields.pluck(:id)).delete_all
      gender_fields.destroy_all
      workday_gender.update(name: 'Gender')
    end

    it 'maps sapling gender(male) to its workday WID - case 1 - success' do
      CustomFieldValue.set_custom_field_value(user, 'Gender', 'Male')
      expect(get_gender_wid(user)).to eq('1')
    end

    it 'maps sapling gender(female) to its workday WID - case 2 - success' do
      CustomFieldValue.set_custom_field_value(user, 'Gender', 'Female')
      expect(get_gender_wid(user)).to eq('2')
    end

    it 'maps sapling gender(not-specified) to its workday WID - case 3 - success' do
      CustomFieldValue.set_custom_field_value(user, 'Gender', 'Not specified')
      expect(get_gender_wid(user)).to eq('3')
    end

    it 'should not map sapling gender(other) to any workday WID - case 4 - failure' do
      CustomFieldValue.set_custom_field_value(user, 'Gender', 'Other')
      expect(get_gender_wid(user)).to eq(nil)
    end

    it 'should not map sapling gender() to any workday WID - case 5 - failure' do
      CustomFieldValue.set_custom_field_value(user, 'Gender', '')
      expect(get_gender_wid(user)).to eq(nil)
    end
  end

  describe '#manage mapping of sapling emergency contact data to workday' do
    before(:each) do
      emergency_contact_relationship_fields = company.custom_fields.where(name: 'Emergency Contact Relationship')
      ProfileTemplateCustomFieldConnection.where(custom_field_id: emergency_contact_relationship_fields.pluck(:id)).delete_all
      emergency_contact_relationship_fields.destroy_all
      workday_emergency_contact_relationship.update(name: 'Emergency Contact Relationship')
      company.custom_fields.where(name: 'Emergency Contact Number').update_all(field_type: 8)
    end

    it 'maps Sapling Emergency Contact Data to Workday Request Params - case 1 - success' do
      CustomFieldValue.set_custom_field_value(user, 'Emergency Contact Name', 'Sapling Emergency Contact Name')
      phone_number_hash.each { |k,v| CustomFieldValue.set_custom_field_value(user, 'Emergency Contact Number', v, k, false) }
      CustomFieldValue.set_custom_field_value(user, 'Emergency Contact Relationship', 'Wife')
      contact_data = get_emergency_contact_data(user)
      expect(contact_data[:first_name]).to eq('Sapling')
      expect(contact_data[:last_name]).to eq('Emergency Contact Name')
      expect(contact_data[:relation_wid]).to eq('1')
      expect(contact_data[:contact_number]).to eq('9898989898')
    end

    it 'maps Sapling Emergency Contact Data (with Missing Contact Number) to Workday Request Params - case 2 - failure' do
      CustomFieldValue.set_custom_field_value(user, 'Emergency Contact Name', 'Sapling Emergency Contact Name')
      CustomFieldValue.set_custom_field_value(user, 'Emergency Contact Relationship', 'Wife')
      contact_data = get_emergency_contact_data(user)
      expect(contact_data[:first_name]).to eq(nil)
      expect(contact_data[:last_name]).to eq(nil)
      expect(contact_data[:relation_wid]).to eq(nil)
      expect(contact_data[:contact_number]).to eq(nil)
    end

    it 'maps Sapling Emergency Contact Data (with Missing Contact Name) to Workday Request Params - case 2 - failure' do
      phone_number_hash.each { |k,v| CustomFieldValue.set_custom_field_value(user, 'Emergency Contact Number', v, k, false) }
      CustomFieldValue.set_custom_field_value(user, 'Emergency Contact Relationship', 'Wife')
      contact_data = get_emergency_contact_data(user)
      expect(contact_data[:first_name]).to eq(nil)
      expect(contact_data[:last_name]).to eq(nil)
      expect(contact_data[:relation_wid]).to eq(nil)
      expect(contact_data[:contact_number]).to eq(nil)
    end

  end

  describe '#manage sapling federal marital status sync over to workday' do
    before(:each) do
      federal_marital_status_fields = company.custom_fields.where(name: 'Federal Marital Status')
      ProfileTemplateCustomFieldConnection.where(custom_field_id: federal_marital_status_fields.pluck(:id)).delete_all
      federal_marital_status_fields.destroy_all
      workday_federal_marital_status.update(name: 'Federal Marital Status')
    end

    it 'updates sapling marital status to workday as married' do
      CustomFieldValue.set_custom_field_value(user, 'Federal Marital Status', 'Married')
      expect(get_marital_status_wid(user)).to eq('1')
    end

    it 'updates sapling marital status to workday as single' do
      CustomFieldValue.set_custom_field_value(user, 'Federal Marital Status', 'Single')
      expect(get_marital_status_wid(user)).to eq('2')
    end

    it 'updates sapling marital status to workday as divorced' do
      CustomFieldValue.set_custom_field_value(user, 'Federal Marital Status', 'Divorced')
      expect(get_marital_status_wid(user)).to eq('3')
    end

    it 'updates sapling marital status to workday as partnered' do
      CustomFieldValue.set_custom_field_value(user, 'Federal Marital Status', 'Partnered')
      expect(get_marital_status_wid(user)).to eq('4')
    end

    it 'updates sapling marital status to workday as separated' do
      CustomFieldValue.set_custom_field_value(user, 'Federal Marital Status', 'Separated')
      expect(get_marital_status_wid(user)).to eq('5')
    end

    it 'should not update sapling marital status to workday' do
      CustomFieldValue.set_custom_field_value(user, 'Federal Marital Status', 'Domestic')
      expect(get_marital_status_wid(user)).to eq(nil)
    end

    it 'should not update sapling marital status to workday' do
      CustomFieldValue.set_custom_field_value(user, 'Federal Marital Status', '')
      expect(get_marital_status_wid(user)).to eq(nil)
    end
  end

  describe '#manage sapling citizenship status sync over to workday' do
    before(:each) do
      workday_citizenship_country
      workday_citizenship_type
    end

    it 'updates sapling citizenship data to workday as citizen' do
      CustomFieldValue.set_custom_field_value(user, 'Citizenship Country', 'USA')
      CustomFieldValue.set_custom_field_value(user, 'Citizenship Type', 'Citizen')
      expect(get_citizenship_data_wid(user)).to eq(['6', '1'])
    end

    it 'should not update sapling citizenship data to workday' do
      CustomFieldValue.set_custom_field_value(user, 'Citizenship Country', '')
      CustomFieldValue.set_custom_field_value(user, 'Citizenship Type', '')
      expect(get_citizenship_data_wid(user)).to eq([nil, nil])
    end
  end

  describe '#manage sapling military service sync over to workday' do
    before(:each) do
      workday_military_service
    end

    it 'updates sapling military service to workday as active' do
      CustomFieldValue.set_custom_field_value(user, 'Military Service', 'Active')
      expect(get_military_status_wid(user)).to eq('1')
    end

    it 'updates sapling military service to workday as inactive' do
      CustomFieldValue.set_custom_field_value(user, 'Military Service', 'Inactive')
      expect(get_military_status_wid(user)).to eq('2')
    end

    it 'should not update sapling military service to workday' do
      CustomFieldValue.set_custom_field_value(user, 'Military Service', '')
      expect(get_military_status_wid(user)).to eq(nil)
    end
  end

  describe '#manage sapling disability sync over to workday' do
    before(:each) do
      workday_disability
    end

    it 'updates sapling disability to workday as speech impairment' do
      CustomFieldValue.set_custom_field_value(user, 'Disability', 'Speech Impairment')
      expect(get_diability_wid(user)).to eq('1')
    end

    it 'updates sapling disability to workday as learning impairment' do
      CustomFieldValue.set_custom_field_value(user, 'Disability', 'Learning Impairment')
      expect(get_diability_wid(user)).to eq('2')
    end

    it 'should not update sapling disability to workday' do
      CustomFieldValue.set_custom_field_value(user, 'Disability', '')
      expect(get_diability_wid(user)).to eq(nil)
    end
  end

  describe '#manage sapling ethnicity sync over to workday' do
    before(:each) do
      race_ethnicity_fields = company.custom_fields.where(name: 'Race/Ethnicity')
      ProfileTemplateCustomFieldConnection.where(custom_field_id: race_ethnicity_fields.pluck(:id)).delete_all
      race_ethnicity_fields.destroy_all
      workday_ethnicity.update(name: 'Race/Ethnicity')
    end

    it 'updates sapling ethnicity to workday as asian' do
      CustomFieldValue.set_custom_field_value(user, 'Race/Ethnicity', 'Asian')
      expect(get_ethnicity_wid(user)).to eq('1')
    end

    it 'updates sapling ethnicity to workday as white' do
      CustomFieldValue.set_custom_field_value(user, 'Race/Ethnicity', 'White')
      expect(get_ethnicity_wid(user)).to eq('2')
    end

    it 'should not update sapling ethnicity to workday' do
      CustomFieldValue.set_custom_field_value(user, 'Race/Ethnicity', '')
      expect(get_ethnicity_wid(user)).to eq(nil)
    end
  end

  describe '#manage sapling legal name sync over to workday' do

    it 'updates sapling first name/last name to workday as first_name/last_name' do
      first_name, last_name = get_user_names(user)
      expect(first_name).to eq(user.first_name)
      expect(last_name).to eq(user.last_name)
    end

  end

  describe '#manage sapling home contact information sync over to workday' do
    before(:each) do
      company.custom_fields.where(name: 'Home Phone Number').update_all(field_type: 8)
      company.custom_fields.where(name: 'Mobile Phone Number').update_all(field_type: 8)
    end

    it 'updates sapling home phone number to workday' do
      phone_number_hash.each {|k,v| CustomFieldValue.set_custom_field_value(user, 'Home Phone Number', v, k, false)}
      country_code, complete_number = get_phone_data('home phone number', user)
      expect(country_code).to eq('USA_1')
      expect(complete_number).to eq('9898989898')
    end

    it 'updates sapling mobile phone number to workday' do
      phone_number_hash.each {|k,v| CustomFieldValue.set_custom_field_value(user, 'Mobile Phone Number', v, k, false)}
      country_code, complete_number = get_phone_data('mobile phone number', user)
      expect(country_code).to eq('USA_1')
      expect(complete_number).to eq('9898989898')
    end

    it 'updates sapling personal email to workday' do
      expect(get_email_address(user)).to eq(user.personal_email)
    end

    it 'updates sapling home address(line 1) to workday(line 1) - Success' do
      address_hash.each do|k,v|
        next if k == 'Line 2'
        CustomFieldValue.set_custom_field_value(user, 'Home Address', v, k, false)
      end

      result = get_address_data(user)
      expect(result[:Address_Line_Data]).to eq(['201 Baker Street'])
      expect(result[:Address_Line_Type]).to eq(['ADDRESS_LINE_1'])
      expect(result[:Postal_Code]).to eq('02101')
      expect(result[:Municipality]).to eq('Boston')
      expect(result[:Country_Region_ID]).to eq('MA')
    end

    it 'updates sapling home address (with missing line 1) to workday - Failure' do
      address_hash.each do|k,v|
        next if k == 'Line 1'
        CustomFieldValue.set_custom_field_value(user, 'Home Address', v, k, false)
      end

      result = get_address_data(user)
      expect(result[:Address_Line_Data]).to eq(nil)
      expect(result[:Address_Line_Type]).to eq(nil)
      expect(result[:Postal_Code]).to eq(nil)
      expect(result[:Municipality]).to eq(nil)
      expect(result[:Country_Region_ID]).to eq(nil)
    end

    it 'updates sapling home address(line 1/line 2) to workday(line 1/line 2)' do
      address_hash.each {|k,v| CustomFieldValue.set_custom_field_value(user, 'Home Address', v, k, false) }
      result = get_address_data(user)
      expect(result[:Address_Line_Data]).to eq(['201 Baker Street', 'Apt #014'])
      expect(result[:Address_Line_Type]).to eq(['ADDRESS_LINE_1', 'ADDRESS_LINE_2'])
      expect(result[:Postal_Code]).to eq('02101')
      expect(result[:Municipality]).to eq('Boston')
      expect(result[:Country_Region_ID]).to eq('MA')
    end
  end

  describe '#manage sapling business title sync over to workday' do
    it 'updates sapling business title to workday' do
      expect(get_business_title(user)).to eq(user.title)
    end
  end

  describe '#manage sapling documents sync over to workday' do
    before do
      attachment.update!(entity_id: user_document_connection.id, entity_type: 'UserDocumentConnection')
    end

    it 'update sapling document to workday when an uploaded file is present' do
      user_document_connection.update!(attached_file_ids: [attachment.id])
      expect(get_worker_document_file(user, {doc_id: user_document_connection.id, file_id: attachment.id})).not_to eq(nil)
    end

    it 'update sapling document to workday when an uploaded file is not present' do
      user_document_connection.update!(attached_file_ids: [])
      expect(get_worker_document_file(user, {doc_id: user_document_connection.id, file_id: nil})).to eq(nil)
    end
  end


  describe '#manage termination of employee in workday' do
    before do
      workday_termination_reason
    end

    it 'terminate employee in workday - Success' do
      user.update!(user_termination_params)
      CustomFieldValue.set_custom_field_value(user, 'Workday Termination Reason', 'Voluntary')
      expect(get_termination_date(workday_request_params_builder.call('terminate_employee', workday_termination_params(user)))).to eq(user.termination_date)
      expect(get_termination_reason_wid(workday_request_params_builder.call('terminate_employee', workday_termination_params(user)))).to eq('1')
    end

    it 'terminate employee in workday - Failure' do
      user.cancel_offboarding
      CustomFieldValue.set_custom_field_value(user, 'Workday Termination Reason', '')
      expect(get_termination_date(workday_request_params_builder.call('terminate_employee', workday_termination_params(user)))).to eq(nil)
      expect(get_termination_reason_wid(workday_request_params_builder.call('terminate_employee', workday_termination_params(user)))).to eq(nil)
    end
  end

  private

  def get_personal_info_data(result)
    result.dig(:Change_Personal_Information_Data, :Personal_Information_Data) || {}
  end
  def get_gender_wid(user)
    get_personal_info_data(request_params_by_field_name('gender', user)).dig(:Gender_Reference, :ID)
  end

  def get_emergency_contact_data(user)
    return {} if (result = request_params_by_field_name('emergency contact name', user)).blank?

    emergency_contact_data = result.dig(:Change_Emergency_Contacts_Data, :Emergency_Contacts_Reference_Data, :Emergency_Contact_Data)
    name_data = emergency_contact_data.dig(:Emergency_Contact_Personal_Information_Data, :Person_Name_Data, :Legal_Name_Data, :Name_Detail_Data)
    { first_name: name_data&.dig(:First_Name), last_name: name_data&.dig(:Last_Name),
      relation_wid: result.dig(:Change_Emergency_Contacts_Data, :Emergency_Contacts_Reference_Data, :Emergency_Contact_Data, :Related_Person_Relationship_Reference, :ID),
      contact_number: emergency_contact_data.dig(:Emergency_Contact_Personal_Information_Data, :Contact_Information_Data, :Phone_Data, :Phone_Number) }
  end

  def get_relationship_wid(user)
    result = request_params_by_field_name('emergency contact relationship', user)
    result.dig(:Change_Emergency_Contacts_Data, :Emergency_Contacts_Reference_Data, :Emergency_Contact_Data, :Related_Person_Relationship_Reference, :ID)
  end

  def get_marital_status_wid(user)
    get_personal_info_data(request_params_by_field_name('federal marital status', user)).dig(:Marital_Status_Reference, :ID)
  end

  def get_citizenship_data_wid(user)
    get_personal_info_data(request_params_by_field_name('citizenship country', user))[:Citizenship_Reference]&.map { |wid| wid&.dig(:ID)} || [nil, nil]
  end

  def get_military_status_wid(user)
    result = request_params_by_field_name('military service', user)
    get_personal_info_data(result).dig(:Military_Information_Data, :Military_Service_Information_Data, :Military_Service_Data, :Military_Status_Reference, :ID)
  end

  def get_diability_wid(user)
    result = request_params_by_field_name('disability', user)
    get_personal_info_data(result).dig(:Disability_Information_Data, :Disability_Status_Information_Data, :Disability_Status_Data, :Disability_Reference, :ID)
  end

  def get_ethnicity_wid(user)
    get_personal_info_data(request_params_by_field_name('race/ethnicity', user)).dig(:Ethnicity_Reference, :ID)
  end

  def get_user_names(user)
    name_data = request_params_by_field_name('first name', user).dig(:Change_Legal_Name_Data, :Name_Data)
    [name_data&.dig(:First_Name), name_data&.dig(:Last_Name)]
  end

  def get_termination_date(result)
    result&.dig(:Terminate_Employee_Data, :Termination_Date)
  end

  def get_termination_reason_wid(result)
    result&.dig(:Terminate_Employee_Data, :Terminate_Event_Data, :Primary_Reason_Reference, :ID)
  end

  def user_termination_params
    {
      termination_type: 'voluntary',
      eligible_for_rehire: 'yes',
      last_day_worked: Date.today,
      termination_date: Date.today
    }.compact
  end

  def phone_number_hash
    {
      'Country' => 'USA',
      'Area code'=> '989',
      'Phone' => '8989898'
    }
  end

  def get_person_contact_info_data(result)
    result.dig(:Change_Home_Contact_Information_Data, :Person_Contact_Information_Data)
  end

  def get_phone_data(field_name, user)
    result = request_params_by_field_name(field_name, user)
    phone_data = get_person_contact_info_data(result).dig(:Person_Phone_Information_Data, :Phone_Information_Data).first[:Phone_Data]
    [phone_data&.dig(:Country_Code_Reference, :ID), phone_data&.dig(:Complete_Phone_Number)]
  end

  def get_email_address(user)
    result = request_params_by_field_name('personal email', user)
    get_person_contact_info_data(result).dig(:Person_Email_Information_Data, :Email_Information_Data, :Email_Data, :Email_Address)
  end

  def address_hash
    {
      'Line 1' => '201 Baker Street',
      'Line 2' => 'Apt #014',
      'Country' => 'United States',
      'State' => 'MA',
      'City' => 'Boston',
      'Zip' => '02101'
    }
  end

  def get_address_data(user)
    result = request_params_by_field_name('home address', user)
    address_data = get_person_contact_info_data(result).dig(:Person_Address_Information_Data, :Address_Information_Data).first[:Address_Data] rescue {}
    {
      Address_Line_Data: address_data.dig(:Address_Line_Data),
      Address_Line_Type: address_data.dig(:attributes!, :Address_Line_Data, :"bsvc:Type"),
      Country_Region_ID: address_data.dig(:Country_Region_Reference, :ID),
      Municipality: address_data.dig(:Municipality),
      Postal_Code: address_data.dig(:Postal_Code)
    }
  end

  def get_business_title(user)
    result = request_params_by_field_name('title', user)
    result.dig(:Change_Business_Title_Business_Process_Data, :Change_Business_Title_Data, :Proposed_Business_Title)
  end

  def get_ssn_id(result)
    result.dig(:Change_Government_IDs_Data, :Government_Identification_data, :National_ID, :National_ID_Data, :ID)
  end

  def get_worker_document_file(user, doc_file_hash)
    request_params_by_field_name('upload_request', user, doc_file_hash)&.dig(:Worker_Document_Data, :File)
  end

  def workday_termination_params(user)
    { user: user, termination_reason: user.get_custom_field_value_workday_wid('Workday Termination Reason') }
  end

  def workday_helper
    HrisIntegrationsService::Workday::Helper.new
  end

  def get_workday_request(user, field_names, section_name, doc_file_hash={})
    params = { user: user, field_names: field_names, doc_file_hash: doc_file_hash, section_name: section_name, helper_object: workday_helper }
    HrisIntegrationsService::Workday::DataBuilder::Workday.new(params).call
  end

  def request_params_by_field_name(field_name, user, doc_file_hash={})
    case field_name
    when 'gender', 'federal marital status', 'military service', 'disability', 'race/ethnicity', 'citizenship type', 'citizenship country'
      get_workday_request(user, [field_name], 'personal_information')
    when 'emergency contact name', 'emergency contact relationship'
      get_workday_request(user, [field_name], 'emergency_contacts')
    when 'first name'
      get_workday_request(user, [field_name], 'legal_name')
    when 'home phone number', 'mobile phone number', 'personal email', 'home address'
      get_workday_request(user, [field_name], 'home_contact_information')
    when 'title'
      get_workday_request(user, [field_name], 'business_title')
    when 'upload_request'
      get_workday_request(user, [field_name], 'worker_document', doc_file_hash)
    end
  end

end
