require 'rails_helper'

RSpec.describe FieldHistory, type: :model do

  describe 'associations' do
    it { should belong_to(:field_changer) }
  end

  describe 'before_creation' do

    context 'field history having integration' do

      before(:all) do
        @company_3 = create(:company, subdomain: 'integration')
        @company_4 = create(:company, subdomain: 'peter')
        @integration = create(:integration, company: @company_3)
        @user = create(:user, company: @company_4)
      end

      it 'is invalid if integration does not belongs to same company as auditable' do
        field_history = FieldHistory.new(field_auditable: @user, integration: @integration, new_value: 'hello')
        expect(field_history.valid?).to eq(false)
      end

      it 'is valid if integration belongs to same company as auditable' do
        @integration.update_column(:company_id, @company_4.id)
        field_history = FieldHistory.new(field_auditable: @user, integration: @integration, new_value: 'hello')
        expect(field_history.valid?).to eq(true)
      end

    end

    context 'validation failed if' do

      before(:all) do
        @company_2 = create(:company, subdomain: 'bar')
        @company_1 = create(:company, subdomain: 'baar')
        @user1 = create(:user, company: @company_2)
        @user2 = create(:user, company: @company_1)
      end

      it 'field history to be created belongs to different company' do
        field_history = FieldHistory.new(field_auditable: @user1, field_changer: @user2, new_value: 'hello')
        expect(field_history.valid?).to eq(false)
      end

      it 'field_history of profile to be created has user belonging to different company' do
        profile = @user1.profile
        field_history = FieldHistory.new(field_auditable: profile, field_changer: @user2, new_value: 'hello')
        expect(field_history.valid?).to eq(false)
      end

      it 'field_history with custom_field has custom_field belonging to different company' do
        custom_field = @company_1.custom_fields.find_by_name("Food Allergies/Preferences")
        field_history = FieldHistory.new(field_auditable: @user1, field_changer: @user2, custom_field: custom_field, new_value: 'hello')
        expect(field_history.valid?).to eq(false)
      end

      it 'field_history for ssn is belonging to a different company' do
        custom_field = @company_1.custom_fields.find_by_name("Social Security Number")
        field_history = FieldHistory.new(field_auditable: @user1, field_changer: @user2, custom_field: custom_field, new_value: '123-123-123')
        expect(field_history.valid?).to eq(false)
      end
    end

    context 'validation successful if' do

      before(:all) do
        @company = create(:company)
        @user2 = create(:user, company: @company)
        @user1 = create(:user, company: @company)
      end

      it 'field history changer and auditable belongs to same company' do
        field_history = FieldHistory.new(field_auditable: @user1, field_changer: @user2, new_value: 'hello')
        expect(field_history.valid?).to eq(true)
      end

      it 'field_history for ssn is belonging to same company' do
        custom_field = @company.custom_fields.find_by_name("Social Security Number")
        field_history = FieldHistory.new(field_auditable: @user1, field_changer: @user1, custom_field: custom_field, new_value: '123-123-123')
        expect(field_history.valid?).to eq(true)
      end

      it 'field_history of profile to be created has user belonging same company' do
        profile = @user1.profile
        field_history = FieldHistory.new(field_auditable: profile, field_changer: @user2, new_value: 'hello')
        expect(field_history.valid?).to eq(true)
      end

      it 'field_history with custom_field has custom_field belonging to same company' do
        custom_field = @company.custom_fields.find_by_name("Food Allergies/Preferences")
        field_history = FieldHistory.new(field_auditable: @user1, field_changer: @user2, custom_field: custom_field, new_value: 'hello')
        expect(field_history.valid?).to eq(true)
      end

    end

  end


  describe '#created' do

    before(:each) do
      @company_object = create(:company)
      User.current = create(:user, company_id: @company_object.id)
      @user = create(:user, company_id: @company_object.id)
    end

    context 'by user' do

      it 'must have a field changer if integration_id is empty' do
        field_history = create(:field_history, field_auditable_id: @user.id, field_auditable_type: "User", field_changer: User.current)
        expect(field_history.integration_id).to be_nil
        expect(field_history.field_changer).not_to be_nil
      end

      it 'must have a custom field id if history is of custom_field' do
        custom_field = @company_object.custom_fields.last
        field_history = create(:field_history, custom_field: custom_field, field_auditable_id: @user.id, field_auditable_type: "User", field_changer: User.current)
        expect(field_history.custom_field_id).not_to be_nil
      end

    end

    context 'by integration' do
      before(:each) do
        company = create(:company)
        @integration2 = create(:integration, company: company)
        @user = create(:user, company: company)
      end

      it 'must have an integration_id' do
        field_history = create(:field_history, integration_id: @integration2.id, field_auditable_id: @user.id, field_auditable_type: "User")
        expect(field_history.integration_id).not_to be_nil
      end

    end

    context 'serialized object with custom field as ssn' do

      before(:each) do
        @ssn_custom_field = create(:custom_field, :ssn_field, company_id: @company_object.id)
      end

      it 'must be non readable for first two parts' do
        field_history = create(:field_history, new_value: '000-00-0000', custom_field_id: @ssn_custom_field.id, field_auditable_id: @user.id, field_auditable_type: "User", field_changer: User.current)
        serialized_object = FieldHistorySerializer::Index.new(field_history)
        ssn = serialized_object.new_value.split('-')
        expect("#{ssn[0]}-#{ssn[1]}").to match("XXX-XX")
      end

    end
  end

  describe '#updated' do

    context 'profile attributes' do

      before do
        @company = FactoryGirl.create(:company)
        @nick = FactoryGirl.create(:nick, company_id: @company.id)
        @sarah = FactoryGirl.create(:sarah, company_id: @company.id)
        User.current = @sarah
      end

      it 'should have changer and auditable belonging to same company' do
        @nick.update(first_name: 'Jake',updated_by_admin: false)
        expect(FieldHistory.all.size).to eq(1)
        expect(FieldHistory.all.first.new_value).to eq('Jake')
        expect(FieldHistory.all.first.new_value).to eq('Jake')
        expect(FieldHistory.all.first.field_changer.company_id).to eq(@company.id)
        expect(FieldHistory.all.first.field_auditable.company_id).to eq(@company.id)
      end

      it 'should not create field history for user having different company' do
        @nick.update_column(:company_id, FactoryGirl.create(:company).id)
        @nick.update(first_name: 'Jake',updated_by_admin: false)
        expect(FieldHistory.all.size).to eq(0)
      end

    end

  end

end
