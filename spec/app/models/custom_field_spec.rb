require 'rails_helper'

RSpec.describe CustomField, type: :model do

  subject(:company) {FactoryGirl.create(:company)}
  subject(:custom_field) {FactoryGirl.create(:custom_field, field_type: 0)}
  let(:user) { create(:user) }
  let(:custom_field_with_value_and_user) { create(:custom_field_with_value_and_user, company_id: company.id) }
  let(:custom_field_with_company) { create(:custom_field, company_id: company.id) }

  context 'field_histories callback' do
    let(:nick){create(:nick, company: company)}
    let(:sarah){create(:sarah, company: company)}
    before do
      User.current = sarah
      @custom_field = create(:custom_field, :with_sub_custom_fields, company: company)
      nested_attributes = []
      @custom_field.sub_custom_fields.each_with_index do |sub_field, index|
        nested_attributes << {value_text: "Hills, Gerhold and Hansen #{index}", user_id: nick.id}
      end
      @custom_field.sub_custom_fields.first.custom_field_values_attributes = nested_attributes
      @custom_field.save!
    end

    it 'should creates history if any subcustom field is created or updated' do
      @custom_field.reload
      expect(@custom_field.field_histories.size).to eq(1)
    end

    it 'should concate all subcstom field values to a single string' do
      resultant_text = "Hills, Gerhold and Hansen 0, Hills, Gerhold and Hansen 1, Hills, Gerhold and Hansen 2"
      @custom_field.reload
      expect(@custom_field.field_histories.first.new_value).to eq(resultant_text)
    end
  end

  describe 'associations' do
    it { should belong_to(:company) }
    it { should belong_to(:company_with_deleted).class_name('Company') }
    it { should belong_to(:custom_table) }
    it { should belong_to(:custom_section) }
    it { should have_many(:custom_field_values).dependent(:destroy) }
    it { should have_many(:custom_field_options).dependent(:nullify) }
    it { should have_many(:sub_custom_fields).dependent(:destroy) }
    it { should have_many(:custom_field_reports).dependent(:destroy) }
    it { should have_many(:field_histories).dependent(:destroy) }
    it { should have_many(:custom_snapshots).dependent(:destroy) }
    it { should have_one(:task) }
  end

  describe 'Nested Attributes' do
    it { should accept_nested_attributes_for(:custom_field_values) }
    it { should accept_nested_attributes_for(:custom_field_options).allow_destroy(true) }
    it { should accept_nested_attributes_for(:sub_custom_fields).allow_destroy(true) }
  end

  describe 'Attribute Accessors' do
    before do
      subject.updating_integration = 'test'
      subject.from_custom_group = 'test'
    end

    it do
      expect(subject.updating_integration).to eq('test')
      expect(subject.from_custom_group).to eq('test')
    end
  end

  describe 'Enums' do
    it do
      should define_enum_for(:section).with([:personal_info, :profile, :additional_fields, :paperwork, :private_info])
      should define_enum_for(:display_location).with([:onboarding, :offboarding, :global])
      should define_enum_for(:integration_group).with([:no_integration, :namely, :bamboo, :paylocity, :adp_wfn, :adp_wfn_profile_creation_and_bamboo_two_way_sync, :custom_group])
      should define_enum_for(:field_type).with([:short_text, :long_text, :multiple_choice, :confirmation, :mcq, :social_security_number, :date, :address, :phone, :simple_phone, :number, :coworker, :multi_select, :employment_status, :currency, :social_insurance_number, :tax, :national_identifier])
      should define_enum_for(:collect_from).with([:new_hire, :admin, :manager])
      should define_enum_for(:ats_integration_group).with([:greenhouse])
      should define_enum_for(:ats_mapping_section).with([:candidate, :job, :jobs, :offer])
    end
  end

  describe 'Model Constants' do
    it do
      expect(CustomField::FIELD_TYPE_WITH_OPTION).to include('mcq','employment_status','multi_select')
      expect(CustomField::FIELD_TYPE_WITH_PLAIN_TEXT).to include('short_text', 'long_text', 'confirmation', 'social_security_number', 'date', 'simple_phone', 'number', 'social_insurance_number')
    end
  end

  describe 'default scope' do
    let!(:field_one) { FactoryGirl.create(:custom_field, position: 2) }
    let!(:field_two) { FactoryGirl.create(:custom_field, position: 1) }

    it 'orders by position' do
      CustomField.where(company_id: nil).all.should eq [field_two, field_one]
    end
  end

    context 'validations' do
    it 'should not create custom field with unique field type' do
      expect { create(:custom_field, company_id: company.id, field_type: 13) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Fieldtype Field type not uniq.')
    end

    it 'should create custom field with unique field name' do
      expect { create(:custom_field, name: 'test_field', company_id: company.id, field_type: 0) }.not_to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Fieldtype Field type not uniq.')
    end

    it 'should not create custom field with non-unique field name' do
      custom_field = create(:custom_field, name: 'test_field', company_id: company.id, field_type: 0, integration_group: CustomField.integration_groups[:namely])
      expect { create(:custom_field, name: 'test_field', company_id: company.id, field_type: 0, integration_group: CustomField.integration_groups[:namely]) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Name  is already in use.')
    end

    it 'should create custom field with name having no double quotes in it' do
      expect { create(:custom_field, name: 'test_field', company_id: company.id, field_type: 0) }.not_to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Name Double quotes and tags are not accepted.')
    end

    it 'should not create custom field with name having double quotes in it' do
      expect { create(:custom_field, name: '"test_field"', company_id: company.id, field_type: 0) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Name Double quotes and tags are not accepted.')
    end
  end

  context 'after save' do
    it 'creates history if any subcustom field is created or updated' do
      User.current = create(:user)
      company_obj = User.current.company
      nested_attributes = {value_text: "Hills, Gerhold and Hansen", user: create(:user, company: company_obj) }
      custom_field = create(:custom_field, :with_sub_custom_fields, company_id: company_obj.id)
      custom_field.sub_custom_fields.first.custom_field_values_attributes = [ nested_attributes ]
      expect{ custom_field.save }.to change{ custom_field.field_histories.count }.by(1)
    end
  end

  it 'should update' do
    expect(custom_field.update(name: 'Hello World')).to eq(true)
  end

  it 'should not update' do
    expect(custom_field.update(name: 'Hello"World')).to eq(false)
  end

  context 'callbacks' do
    context 'before destroy' do
      it 'should nullify custom field values' do
        User.current = create(:user)
        company = User.current.company
        custom_field = create(:custom_field_with_value, company_id: company.id)
        expect { custom_field.destroy }.to change{ custom_field.custom_field_values.count }.to eq(0)
      end

      it 'should nullify custom field tasks' do
        custom_field = create(:custom_field_with_task, company_id: company.id)
        custom_field._run_destroy_callbacks do
          expect(custom_field.reload.task).to be_nil
        end
      end
    end

    context 'after create' do
      it 'should update namely ids' do
        FactoryGirl.create(:namely_integration, company: company)
        Sidekiq::Testing.inline! do
          expect { create(:custom_field, name: 'test_field', company: company, field_type: 1, integration_group: CustomField.integration_groups[:namely]) }.not_to raise_error
        end
      end

      it 'should update bamboo options' do
        FactoryGirl.create(:bamboo_integration, company: company)
        Sidekiq::Testing.inline! do
          expect { create(:custom_field, name: 'test_field', company: company, field_type: 2, integration_group: CustomField.integration_groups[:bamboo]) }.not_to raise_error
        end
      end

      it 'should update bamboo options with two-way sync' do
        create(:integration, company: company, api_name: "adp_wfn_us", is_enabled: true, secret_token: "thisIsAdummySecretTokenthisIsAdummySecretTokenthisIsAdummySecretToken", subdomain: 'sapling-sandbox')
        FactoryGirl.create(:bamboo_integration, company: company)
        Sidekiq::Testing.inline! do
          expect { create(:custom_field, name: 'test_field', company: company, field_type: 2, integration_group: CustomField.integration_groups[:adp_wfn_profile_creation_and_bamboo_two_way_sync]) }.not_to raise_error
        end
      end

      it 'should generate an api key' do
        custom_field = create(:custom_field, name: 'test_field', company: company, field_type: 2, integration_group: CustomField.integration_groups[:adp_wfn_profile_creation_and_bamboo_two_way_sync])
        expect (custom_field.api_field_id).should_not eq nil
      end

      it 'should intialize custom group position' do
        custom_table = FactoryGirl.create(:custom_table)
        custom_field = create(:custom_field, name: 'test_field', company: company, field_type: 2, integration_group: CustomField.integration_groups[:adp_wfn_profile_creation_and_bamboo_two_way_sync], from_custom_group: true, custom_table_id: custom_table.id)
        expect (custom_field.position).should_not eq nil
      end

      it 'should create default custom_snapshots for custom table snapshots' do
        custom_table = FactoryGirl.create(:custom_table)
        custom_table_user_snapshot = FactoryGirl.create(:custom_table_user_snapshot, custom_table: custom_table, state: 0, user: user, effective_date: Date.today)
        custom_field = create(:custom_field, name: 'test_field', company: company, field_type: 2, integration_group: CustomField.integration_groups[:adp_wfn_profile_creation_and_bamboo_two_way_sync], from_custom_group: true, custom_table_id: custom_table.id)
        custom_table_user_snapshot_received = custom_field.custom_table.custom_table_user_snapshots.first
        expect(custom_table_user_snapshot_received).to eq(custom_table_user_snapshot)
      end
    end

    context 'after update' do
      it 'should remove empty hire manager forms' do
        custom_field = FactoryGirl.create(:custom_field, field_type: 0, collect_from: 0, company: company)
        user = create(:user, is_form_completed_by_manager: User.is_form_completed_by_managers[:incompleted], company: company)
        custom_field.collect_from = 1
        custom_field.save
        expect(custom_field.company.users.where(is_form_completed_by_manager: User.is_form_completed_by_managers[:incompleted]).count).to eq(0)
      end

      it 'should update namely ids' do
        FactoryGirl.create(:namely_integration, company: company)
        custom_field = FactoryGirl.create(:custom_field, field_type: 0, collect_from: 0, company: company, mapping_key: 'test_mapping_key', integration_group: CustomField.integration_groups[:namely])
        custom_field.mapping_key = 'test_mapping_key_2'
        Sidekiq::Testing.inline! do
          expect { custom_field.save }.not_to raise_error
        end
      end

      it 'should update bamboo options' do
        FactoryGirl.create(:bamboo_integration, company: company)
        custom_field = FactoryGirl.create(:custom_field, field_type: 0, collect_from: 0, company: company, mapping_key: 'test_mapping_key', integration_group: CustomField.integration_groups[:bamboo])
        custom_field.mapping_key = 'test_mapping_key_2'
        Sidekiq::Testing.inline! do
          expect { custom_field.save }.not_to raise_error
        end
      end

      it 'should update bamboo options with two-way sync' do
        create(:integration, company: company, api_name: "adp_wfn_us", is_enabled: true, secret_token: "thisIsAdummySecretTokenthisIsAdummySecretTokenthisIsAdummySecretToken", subdomain: 'sapling-sandbox')
        FactoryGirl.create(:bamboo_integration, company: company)
        custom_field = FactoryGirl.create(:custom_field, field_type: 0, collect_from: 0, company: company, mapping_key: 'test_mapping_key', integration_group: CustomField.integration_groups[:adp_wfn_profile_creation_and_bamboo_two_way_sync])
        custom_field.mapping_key = 'test_mapping_key_2'
        Sidekiq::Testing.inline! do
          expect { custom_field.save }.not_to raise_error
        end
      end
    end

    context 'after commit' do
      let(:custom_field_with_value_and_user) { FactoryGirl.create(:custom_field_with_value_and_user, company: company) }
      context 'on create' do
        it 'should flush cache' do
          expect(custom_field_with_value_and_user.run_callbacks(:commit)).to be_truthy
        end
      end

      context 'on update' do
        it 'should flush cache' do
          custom_field_with_value_and_user.field_type = 1
          custom_field_with_value_and_user.save
          expect(custom_field_with_value_and_user.run_callbacks(:commit)).to be_truthy
        end
      end

      context 'on destroy' do
        it 'should flush cache' do
          custom_field_with_value_and_user.destroy
          expect(custom_field_with_value_and_user.run_callbacks(:commit)).to be_truthy
        end
      end
    end
  end

  describe '#typehHasSubFields' do
    it 'should return true when sub field type is valid' do
      expect(CustomField.typehHasSubFields('address')).to eq(true)
      expect(CustomField.typehHasSubFields('phone')).to eq(true)
      expect(CustomField.typehHasSubFields('currency')).to eq(true)
    end

    it 'should return false when sub field type is invalid' do
      expect(CustomField.typehHasSubFields('test')).to eq(false)
    end
  end

  describe '#parse_phone_string_to_hash' do
    it 'should parse phone string to hash' do
      expect(CustomField.parse_phone_string_to_hash('202-456-1414')).to eq({:country_alpha3=>"USA", :area_code=>"202", :phone=>"4561414"})
    end

    it 'should not parse an invalid phone string to hash' do
      expect(CustomField.parse_phone_string_to_hash('1234567')).to eq(nil)
    end
  end

  describe '#get_custom_field' do
    it 'should return custom field of specific name' do
      custom_field = create(:custom_field, company: company)
      expect(CustomField.get_custom_field(company, custom_field.name)).to eq(custom_field)
    end
  end

  describe '#get_sub_custom_field_value' do
    it 'should return sub custom field of specific field' do
      custom_field = create(:custom_field, :with_sub_custom_fields, company_id: company.id)
      create(:custom_field_value, :belonging_to_subcustom_field, sub_custom_field: custom_field.sub_custom_fields.first, user: user)
      custom_field.reload
      Rails.cache.delete([custom_field.sub_custom_fields.first.id, user.id, 'sub_custom_field_values'])
      expect(CustomField.get_sub_custom_field_value(custom_field, custom_field.sub_custom_fields.first.name, user.id)).to eq(custom_field.sub_custom_fields.first.custom_field_values.first.value_text)
    end
  end

  describe '#get_custom_field_value' do
    it 'should return custom field value of specific field' do
      custom_field = custom_field_with_value_and_user
      custom_field_value = custom_field.custom_field_values.first
      Rails.cache.delete([custom_field.id, custom_field_value.user.id, 'custom_field_values'])
      expect(CustomField.get_custom_field_value(custom_field, custom_field_value.user.id)).to eq(custom_field_value.value_text)
    end
  end

  describe '#get_coworker_value' do
    it 'should return custom field value of specific field' do
      user = create(:user, company: company)
      custom_field = custom_field_with_company
      create(:custom_field_value, custom_field: custom_field, coworker: user, user: user)
      custom_field_value = custom_field.custom_field_values.first
      Rails.cache.delete([custom_field.id, custom_field_value.user.id, 'custom_field_values'])
      expect(CustomField.get_coworker_value(custom_field, custom_field_value.user.id)).to eq(custom_field_value.coworker)
    end
  end

  describe '#get_mcq_custom_field_value' do
    it 'should return custom field value of specific field' do
      custom_field = custom_field_with_company
      custom_field_option = create(:custom_field_option, custom_field: custom_field, option: 'test')
      custom_field_value = create(:custom_field_value, custom_field: custom_field, custom_field_option: custom_field_option, user: user)
      Rails.cache.delete([custom_field.id, user.id, 'custom_field_values'])
      custom_field.reload
      expect(CustomField.get_mcq_custom_field_value(custom_field, user.id)).to eq(custom_field.custom_field_options.first.option)
    end
  end

  describe '#get_multiselect_custom_field_value' do
    it 'should return multi select custom field value of specific field' do
      custom_field = custom_field_with_company
      custom_field_option = create(:custom_field_option, custom_field: custom_field, option: 'test')
      custom_field_value = create(:custom_field_value, custom_field: custom_field, custom_field_option: custom_field_option, user: user, checkbox_values: ["#{custom_field.custom_field_options.first.id}"])
      Rails.cache.delete([custom_field.id, user.id, 'custom_field_values'])
      expect(CustomField.get_multiselect_custom_field_value(custom_field, user.id)).to eq('test')
    end
  end

  describe '#convert_phone_number_to_international_phone_number' do
    it 'should convert phone number to international phone number' do
      custom_field = custom_field_with_company
      custom_field_value = create(:custom_field_value, value_text: '202-456-1414', custom_field: custom_field, user: user)
      Rails.cache.delete([custom_field.id, user.id, 'custom_field_values'])
      expect(CustomField.convert_phone_number_to_international_phone_number(custom_field, user.id)).to eq({:country_alpha3=>"USA", :area_code=>"202", :phone=>"4561414"})
    end
  end

  describe '#get_multiselect_custom_field_value' do
    it 'should return multi select custom field value of specific field' do
      custom_field = custom_field_with_company
      custom_field_option = create(:custom_field_option, custom_field: custom_field, option: 'test')
      custom_field.reload
      custom_field_value = create(:custom_field_value, custom_field: custom_field, custom_field_option: custom_field_option, user: user, checkbox_values: ["#{custom_field.custom_field_options.first.id}"])
      Rails.cache.delete([custom_field.id, user.id, 'custom_field_values'])
      expect(custom_field.checkbox_values(user.id)).to eq('test')
    end
  end

  describe '#get_custom_field_values_by_user' do
    it 'should return multi select custom field value of specific field' do
      custom_field = custom_field_with_value_and_user
      custom_field_value = custom_field.custom_field_values.first
      Rails.cache.delete([custom_field.id, custom_field_value.user.id, 'custom_field_values'])
      expect(custom_field.get_custom_field_values_by_user(custom_field_value.user.id)).to eq(custom_field_value)
    end
  end

  describe '#get_changed_sub_custom_field_values' do
    it 'should return multi select custom field value of specific field' do
      custom_field = create(:custom_field, :with_sub_custom_fields, company: company)
      create(:custom_field_value, sub_custom_field: custom_field.sub_custom_fields.first)
      custom_field.reload
      sub_custom_field_value = custom_field.sub_custom_fields.first.custom_field_values.first
      sub_custom_field_value.value_text = 'test'
      expect(sub_custom_field_value.changed?).to eq(true)
    end
  end

  describe 'after_create#create_custom_table_default_snapshots' do
    it 'should create create default custom snapshot on creating field in custom table and check value which should be nil by default' do
      custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information])
      role_information_ctus = create(:role_information_custom_snapshot, user_id: user.id, custom_table_id: custom_table.id, effective_date: Date.today.strftime("%B %d, %Y"))

      custom_snapshot_count = user.custom_table_user_snapshots.where(custom_table_id: custom_table.id).take.custom_snapshots.count
      new_custom_field = create(:custom_table_custom_field, field_type: 0, section: nil, company: company, custom_table: custom_table, name: 'custom table field')

      expect(user.custom_table_user_snapshots.where(custom_table_id: custom_table.id).take.custom_snapshots.count).to eq(custom_snapshot_count+1)
      expect(user.custom_table_user_snapshots.where(custom_table_id: custom_table.id).take.custom_snapshots.find_by(custom_field_id: new_custom_field).custom_field_value).to be_nil
    end
  end
end
