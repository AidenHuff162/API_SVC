require 'rails_helper'

RSpec.describe Integrations::MigrateCustomFieldDataToAnotherCustomFieldJob, type: :job do

  let(:company) { create(:company, subdomain: 'rocketship') }

  it "returns if company id is not present" do
    response = Integrations::MigrateCustomFieldDataToAnotherCustomFieldJob.perform_now()
    expect(response).to be == nil
  end

  it "returns if custom field name is not present" do
    response = Integrations::MigrateCustomFieldDataToAnotherCustomFieldJob.perform_now(company.id)
    expect(response).to be == nil
  end

  describe 'migrates race/ethnicity data into the other field' do
    it 'checks custom field count and field type' do
      custom_fields = CustomField.where(company_id: company.id, name: 'Race/Ethnicity')
      custom_fields.take.update(field_type: CustomField.field_types[:short_text])
      expect(custom_fields.count).to eq(1)
      expect(custom_fields.first.field_type).to eq('short_text')
    end

    it 'checks data migrate correctly from value text to option id - example 1' do
      options = [ 'American Indian or Alaska Native', 'Asian', 'Black or African American', 'Hispanic or Latino',
        'Native Hawaiian or Other Pacific Islander', 'Two or more races', 'White' ]

      custom_fields = CustomField.where(company_id: company.id, name: 'Race/Ethnicity')
      custom_fields.take.update(field_type: CustomField.field_types[:short_text])

      user = create(:user, company: company)
      cfv = CustomFieldValue.find_or_initialize_by(custom_field_id: custom_fields.first.id, user_id: user.id)
      cfv.value_text = 'White'
      cfv.save!

      Integrations::MigrateCustomFieldDataToAnotherCustomFieldJob.perform_now(company.id, 'Race/Ethnicity', options)

      custom_fields = CustomField.where(company_id: company.id, name: 'Race/Ethnicity')
      expect(user.get_custom_field_value_text('Race/Ethnicity')).to eq('White')
      custom_field_values = user.custom_field_values.where(custom_field_id: custom_fields.first.id)
      expect(custom_field_values.count).to eq(1)
      expect(custom_field_values.first.custom_field_option.option).to eq('White')
    end

    it 'checks data migrate correctly from value text to option id - example 2' do
      options = [ 'American Indian or Alaska Native', 'Asian', 'Black or African American', 'Hispanic or Latino',
        'Native Hawaiian or Other Pacific Islander', 'Two or more races', 'White' ]

      custom_fields = CustomField.where(company_id: company.id, name: 'Race/Ethnicity')
      custom_fields.take.update(field_type: CustomField.field_types[:short_text])

      user = create(:user, company: company)
      cfv = CustomFieldValue.find_or_initialize_by(custom_field_id: custom_fields.first.id, user_id: user.id)
      cfv.value_text = 'Asian'
      cfv.save!

      Integrations::MigrateCustomFieldDataToAnotherCustomFieldJob.perform_now(company.id, 'Race/Ethnicity', options)
      custom_fields = CustomField.where(company_id: company.id, name: 'Race/Ethnicity')
      expect(user.get_custom_field_value_text('Race/Ethnicity')).to eq('Asian')
      custom_field_values = user.custom_field_values.where(custom_field_id: custom_fields.first.id)
      expect(custom_field_values.count).to eq(1)
      expect(custom_field_values.first.custom_field_option.option).to eq('Asian')
    end

    it 'checks data migrate correctly from value text to nil - example 3' do
      options = [ 'American Indian or Alaska Native', 'Asian', 'Black or African American', 'Hispanic or Latino',
        'Native Hawaiian or Other Pacific Islander', 'Two or more races', 'White' ]

      custom_fields = CustomField.where(company_id: company.id, name: 'Race/Ethnicity')
      custom_fields.take.update(field_type: CustomField.field_types[:short_text])

      user = create(:user, company: company)
      cfv = CustomFieldValue.find_or_initialize_by(custom_field_id: custom_fields.first.id, user_id: user.id)
      cfv.value_text = 'Asian 11'
      cfv.save!

      Integrations::MigrateCustomFieldDataToAnotherCustomFieldJob.perform_now(company.id, 'Race/Ethnicity', options)
      custom_fields = CustomField.where(company_id: company.id, name: 'Race/Ethnicity')
      expect(user.get_custom_field_value_text('Race/Ethnicity')).to eq(nil)
      custom_field_values = user.custom_field_values.where(custom_field_id: custom_fields.first.id)
      expect(custom_field_values.count).to eq(0)
    end
  end

  describe 'migrates federal marital status data into the other field' do
    it 'checks custom field count and field type' do
      custom_fields = CustomField.where(company_id: company.id, name: 'Federal Marital Status')
      expect(custom_fields.count).to eq(1)
      expect(custom_fields.first.field_type).to eq('mcq')
    end

    it 'checks data migrate correctly from value text to option id - example 1' do
      options = [ 'Single', 'Married', 'Common Law', 'Domestic Partnership' ]

      custom_fields = CustomField.where(company_id: company.id, name: 'Federal Marital Status')

      user = create(:user, company: company)
      cfv = CustomFieldValue.find_or_initialize_by(custom_field_id: custom_fields.first.id, user_id: user.id)
      cfv.value_text = 'Single'
      cfv.save!

      Integrations::MigrateCustomFieldDataToAnotherCustomFieldJob.perform_now(company.id, 'Federal Marital Status', options)
      custom_fields = CustomField.where(company_id: company.id, name: 'Federal Marital Status')
      expect(user.get_custom_field_value_text('Federal Marital Status')).to eq('Single')
      custom_field_values = user.custom_field_values.where(custom_field_id: custom_fields.first.id)
      expect(custom_field_values.count).to eq(1)
      expect(custom_field_values.first.custom_field_option.option).to eq('Single')
    end

    it 'checks data migrate correctly from value text to nil - example 2' do
      options = [ 'Single', 'Married', 'Common Law', 'Domestic Partnership' ]

      custom_fields = CustomField.where(company_id: company.id, name: 'Federal Marital Status')

      user = create(:user, company: company)
      cfv = CustomFieldValue.find_or_initialize_by(custom_field_id: custom_fields.first.id, user_id: user.id)
      cfv.value_text = 'Head of household'
      cfv.save!

      Integrations::MigrateCustomFieldDataToAnotherCustomFieldJob.perform_now(company.id, 'Federal Marital Status', options)
      custom_fields = CustomField.where(company_id: company.id, name: 'Federal Marital Status')
      expect(user.get_custom_field_value_text('Federal Marital Status')).to eq(nil)
      custom_field_values = user.custom_field_values.where(custom_field_id: custom_fields.first.id)
      expect(custom_field_values.count).to eq(0)
    end
  end
end

