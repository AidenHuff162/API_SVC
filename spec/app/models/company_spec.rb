require 'rails_helper'

RSpec.describe Company, type: :model do
  describe 'Associations' do
    it { is_expected.to have_many(:users) }
    it { is_expected.to have_many(:teams) }
    it { is_expected.to have_many(:locations) }
    it { is_expected.to have_many(:milestones) }
    it { is_expected.to have_many(:company_values) }
    it { is_expected.to have_many(:company_emails) }
    it { is_expected.to have_many(:custom_sections) }
    it { is_expected.to have_many(:gallery_images).class_name('UploadedFile::GalleryImage') }
    it { is_expected.to have_one(:landing_page_image).class_name('UploadedFile::LandingPageImage') }
    it { is_expected.to have_one(:display_logo_image).class_name('UploadedFile::DisplayLogoImage') }
    it { is_expected.to belong_to(:owner).class_name('User') }
    it { is_expected.to have_many(:paperwork_templates) }
    it { is_expected.to have_many(:documents) }
    it { is_expected.to have_many(:paperwork_requests).through(:documents) }
    it { is_expected.to have_many(:document_upload_requests) }
    it { is_expected.to have_many(:document_connection_relations).through(:document_upload_requests) }
    it { is_expected.to have_many(:user_document_connections).through(:document_connection_relations) }
    it { is_expected.to have_many(:sftps).dependent(:destroy) }
  end

  describe 'custom sections' do
    it 'should create custom sections for a company' do
      company = FactoryGirl.create(:company)
      expect(company.custom_sections.count).to eq(4)
    end

    it 'prefrence fields with profile_setup as profile_fields should contain custom section id, profile fields should be associated with custom sections' do
      company = FactoryGirl.create(:company)
      expect(company.prefrences["default_fields"][0].keys).to include('custom_section_id')
      profile_fields = company.prefrences["default_fields"].select {|f| f['profile_setup'] == 'profile_fields'}
      profile_fields.try(:each) do |field|
        custom_section = CustomSection.find_by(id: field['custom_section_id'])
        expect(field['section']).to eq(custom_section.section)
      end
    end

    it 'prefrence fields with profile_setup as custom_table should contain custom section id and value should not present' do
      company = FactoryGirl.create(:company)
      custom_table_fields = company.prefrences["default_fields"].select {|f| f['profile_setup'] == 'custom_table'}
      custom_table_fields.try(:each) do |field|
        expect(field['section'].empty?).to eq(true)
      end
    end

    it 'default custom fields should contains custom section id, custom fields should be associated with custom sections' do
      company = FactoryGirl.create(:company)
      expect(company.custom_fields.first.attributes).to include('custom_section_id')
      custom_fields = company.custom_fields.where.not(custom_section_id: nil)
      custom_fields.try(:each) do |field|
        custom_section = CustomSection.find_by(id: field.custom_section_id)
        expect(field.section).to eq(custom_section.section)
      end
    end
  end

  describe 'update calendar event' do
    it 'creates holidays calendar events if calendar is enabled' do
      company = FactoryGirl.create(:company, enabled_calendar: true)
      FactoryGirl.create(:holiday, company: company)
      expect(company.holidays.first.calendar_event.eventable_id).to eq(company.holidays.first.id)
    end

    it 'does not create holidays calendar events if calendar is disabled' do
      company = FactoryGirl.create(:company, enabled_calendar: false)
      FactoryGirl.create(:holiday, company: company)
      expect(company.holidays.first.calendar_event).to eq(nil)
    end

    it 'deletes holidays calendar events when calendar is disabled' do
      Sidekiq::Testing.inline! do
        company = FactoryGirl.create(:company, enabled_calendar: true)
        FactoryGirl.create(:holiday, company: company)
        company.update(enabled_calendar: false)
        expect(company.holidays.first.calendar_event).to eq(nil)
      end
    end

    it 're creates holidays calendar events when calendar is enabled' do
      Sidekiq::Testing.inline! do
        company = FactoryGirl.create(:company, enabled_calendar: false)
        FactoryGirl.create(:holiday, company: company)
        company.update(enabled_calendar: true)
        expect(company.holidays.first.calendar_event.eventable_id).to eq(company.holidays.first.id)
      end
    end
  end

  describe 'user id' do
    it 'contains user id in prefrence fields at 1st position' do
      company = FactoryGirl.create(:company)
      expect(company.prefrences["default_fields"][0]["name"]).to eq("User ID")
    end

    it 'contains user id in prefrence fields in personal info section' do
      company = FactoryGirl.create(:company)
      expect(company.prefrences["default_fields"][0]["section"]).to eq("personal_info")
    end
  end

  describe 'milestones' do
    it 'should create and assign a milestone to a company' do
      current_company = FactoryGirl.create(:company)
      milestone = FactoryGirl.create(:milestone, company: current_company)
      expect(current_company.milestones.first).to eq(milestone)
    end

    it 'should update a milestone in a company' do
      current_company = FactoryGirl.create(:company)
      FactoryGirl.create(:milestone, company: current_company)

      expect(current_company.milestones.count).to eq(1)

      m1 = current_company.milestones.first
      update_with = FactoryGirl.create(:milestone)

      m1.name = update_with.name
      m1.description = update_with.description
      expect(m1.save).to eq(true)
    end

    it 'should delete a milestone in the company' do
      current_company = FactoryGirl.create(:company)
      FactoryGirl.create(:milestone, company: current_company)
      expect(current_company.milestones.count).to eq(1)
      current_company.milestones.first.destroy
      expect(current_company.milestones.count).to eq(0)
    end
  end

  describe 'mappings' do
    it 'should return all custom fields of a company' do
      company = FactoryGirl.create(:company)
      expect(company.get_custom_fields_for_mapping('all_fields').count).to eq(26)
    end

    it 'should return grouped custom fields of a company' do
      company = FactoryGirl.create(:company)
      expect(company.get_custom_fields_for_mapping('custom_groups').count).to eq(1)
    end

    it 'should return all default fields of a company' do
      company = FactoryGirl.create(:company)
      expect(company.default_field_prefrences_for_mapping('all_fields').count).to eq(23)
    end

    it 'should return grouped default fields of a company' do
      company = FactoryGirl.create(:company)
      expect(company.default_field_prefrences_for_mapping('custom_groups').count).to eq(2)
    end
  end


  describe '#adp_templates_enabled' do
    let(:us_integration_instance_active) { create(:adp_wfn_us_integration, state: :active) }
    let(:us_integration_instance_inactive) { create(:adp_wfn_us_integration, state: :inactive) }
    let(:can_integration_instance_active) { create(:adp_wfn_can_integration, state: :active) }
    let(:can_integration_instance_inactive) { create(:adp_wfn_can_integration, state: :inactive) }

    context 'when ADP US is enabled' do
      it('should return true') do
        company = us_integration_instance_active.company
        expect(company.adp_templates_enabled).to be true
      end
    end

    context 'when ADP CAN is enabled' do
      it('should return true') do
        company = can_integration_instance_active.company
        expect(company.adp_templates_enabled).to be true
      end
    end

    context 'when ADP US is inactive' do
      it('should return false') do
        company = us_integration_instance_inactive.company
        expect(company.adp_templates_enabled).to be false
      end
    end

    context 'when ADP CAN is inactive' do
      it('should return false') do
        company = can_integration_instance_inactive.company
        expect(company.adp_templates_enabled).to be false
      end
    end

    context 'when there are no ADP WFN integrations' do
      it('should return false') do
        company = FactoryGirl.create(:company)
        expect(company.adp_templates_enabled).to be false
      end
    end
  end

  describe '#adp_us_company_code_enabled' do
    context 'when integration instance is present' do

      let(:integration_instance_active) { create(:adp_wfn_us_integration, state: :active) }
      let(:integration_instance_inactive) { create(:adp_wfn_us_integration, state: :inactive) }

      it('should return true when enabled') do
        company = integration_instance_active.company
        expect(company.adp_us_company_code_enabled).to be true
      end

      it('should return nil when disabled') do
        company = integration_instance_inactive.company
        expect(company.adp_us_company_code_enabled).to be nil
      end
    end

    context 'when integration instance does not exist' do
      it('should return nil') do
        company = FactoryGirl.create(:company)
        expect(company.adp_us_company_code_enabled).to be nil
      end
    end
  end

  describe '#adp_can_company_code_enabled' do
    context 'when integration instance is present' do

      let(:integration_instance_active) { create(:adp_wfn_can_integration, state: :active) }
      let(:integration_instance_inactive) { create(:adp_wfn_can_integration, state: :inactive) }

      it('should return true when enabled') do
        company = integration_instance_active.company
        expect(company.adp_can_company_code_enabled).to be true
      end

      it('should return nil when disabled') do
        company = integration_instance_inactive.company
        expect(company.adp_can_company_code_enabled).to be nil
      end
    end

    context 'when integration instance does not exist' do
      it('should return nil') do
        company = FactoryGirl.create(:company)
        expect(company.adp_can_company_code_enabled).to be nil
      end
    end
  end

  describe '#adp_company_code_enabled' do

    let(:us_integration_instance_active) { create(:adp_wfn_us_integration, state: :active) }
    let(:us_integration_instance_inactive) { create(:adp_wfn_us_integration, state: :inactive) }
    let(:can_integration_instance_active) { create(:adp_wfn_can_integration, state: :active) }
    let(:can_integration_instance_inactive) { create(:adp_wfn_can_integration, state: :inactive) }

    context 'when ADP US is enabled' do
      it('should return true') do
        company = us_integration_instance_active.company
        expect(company.adp_company_code_enabled).to be true
      end
    end

    context 'when ADP CAN is enabled' do
      it('should return true') do
        company = can_integration_instance_active.company
        expect(company.adp_company_code_enabled).to be true
      end
    end

    context 'when ADP US is inactive' do
      it('should return false') do
        company = us_integration_instance_inactive.company
        expect(company.adp_company_code_enabled).to be false
      end
    end

    context 'when ADP CAN is inactive' do
      it('should return false') do
        company = can_integration_instance_inactive.company
        expect(company.adp_company_code_enabled).to be false
      end
    end

    context 'when there are no ADP WFN integrations' do
      it('should return false') do
        company = FactoryGirl.create(:company)
        expect(company.adp_company_code_enabled).to be false
      end
    end
  end

  describe '#asana_integration_enabled' do
    let(:integration_instance_active) { create(:asana_instance) }

    it('should return false when no instance exists') do
      company = FactoryGirl.create(:company)
      expect(company.asana_integration_enabled).to be false
    end

    it('should return true when an instance exists') do
      company = integration_instance_active.company
      expect(company.asana_integration_enabled).to be true
    end
  end

  describe '#can_provision_adfs?' do
    context 'when integration instance is present' do

      let(:integration_instance_active) { create(:adfs_productivity_integration_instance, state: :active) }
      let(:integration_instance_inactive) { create(:adfs_productivity_integration_instance, state: :inactive) }

      it('should return true when enabled') do
        company = integration_instance_active.company
        expect(company.can_provision_adfs?).to be true
      end

      it('should return false when disabled') do
        company = integration_instance_inactive.company
        expect(company.can_provision_adfs?).to be false
      end
    end

    context 'when integration instance does not exist' do
      it('should return false') do
        company = FactoryGirl.create(:company)
        expect(company.can_provision_adfs?).to be false
      end
    end
  end

  describe '#create_default_email_templates' do
    it('should possess the set of default templates after create') do
      company = create(:company)
      expected_templates = %w[
        new_buddy new_manager manager_form preboarding new_activites_assigned new_manager_form document_completion
        onboarding_activity_notification transition_activity_notification offboarding_activity_notification
        new_pending_hire start_date_change invite_user invitation
      ]
      templates = company.email_templates.pluck(:email_type)
      expect(templates).to contain_exactly(*expected_templates)
    end
  end

end
