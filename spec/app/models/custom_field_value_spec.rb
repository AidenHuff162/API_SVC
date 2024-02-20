require 'rails_helper'

RSpec.describe CustomFieldValue, type: :model do

  describe '#after_save' do
    context 'track_changes for changed fields' do

      before(:each) do
        @company = FactoryGirl.create(:company)
        @nick = FactoryGirl.create(:nick, company_id: @company.id)
        @sarah = FactoryGirl.create(:sarah, company_id: @company.id)
        @custom_field = FactoryGirl.create(:custom_field, :user_info_and_profile_custom_field, company_id: @company.id)
        User.current = @sarah
      end

      it 'creates history for profile and employee record custom fields' do
        custom_field_value = build(:custom_field_value, :value_of_personal_info_custom_field, user_id: @nick.id, custom_field_id: @custom_field.id)
        expect{ custom_field_value.save }.to change{ custom_field_value.user.field_histories.count }.by(1)
      end

    end

    context 'track changes for custom fields' do
      let(:option) { create(:custom_field_option, :gender_male) }

      before(:each) do
        @company = FactoryGirl.create(:company)
        @nick = FactoryGirl.create(:nick, company_id: @company.id)
        @sarah = FactoryGirl.create(:sarah, company_id: @company.id)
        User.current = @sarah
      end

      it 'logs history for changer and custom field belonging to same company' do
        custom_field = CustomField.where(name: "Gender", company_id: @company.id).first
        custom_field_value = create(:custom_field_value, custom_field_id: custom_field.id, custom_field_option_id: option.id, user_id: @nick.id, encrypted_value_text: nil)
        expect(FieldHistory.all.size).to eq(1)
        expect(FieldHistory.first.new_value).to eq("Male")
        expect(FieldHistory.first.field_changer.company_id).to eq(FieldHistory.first.field_auditable.company_id)
      end

      it 'does not log history for changer and custom field not belonging to same company' do
        custom_field = CustomField.where(name: "Gender", company_id: FactoryGirl.create(:company).id).first
        expect { create(:custom_field_value, custom_field_id: custom_field.id, custom_field_option_id: option.id, user_id: @nick.id, encrypted_value_text: nil) }.to raise_error
      end

    end

  end

end
