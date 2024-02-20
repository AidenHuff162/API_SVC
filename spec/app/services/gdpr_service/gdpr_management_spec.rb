require 'rails_helper'

RSpec.describe GdprService::GdprManagement do

  describe '#perform' do
    context 'should anonymize data and save in anonymize datum for departed user if GDPR not applied yet' do
      before(:all) do
        @user = create(:departed_user_with_no_gdpr, termination_date: 400.days.ago, gdpr_action_date: 1.day.ago, company: create(:company, subdomain: 'GDPR-SERVICES-1'))
        create(:general_data_protection_regulation, company: @user.company)
        
        @phone_field_with_value = create(:phone_field_with_value, user: @user, company: @user.company)
        @sin_field_with_value = create(:sin_field_with_value, user: @user, company: @user.company)
        
        @address_custom_fields = @user.company.custom_fields.where(field_type: CustomField.field_types[:address])
        @simple_phone_custom_fields = @user.company.custom_fields.where(field_type: CustomField.field_types[:simple_phone])
        @social_security_number_fields = @user.company.custom_fields.where(field_type: CustomField.field_types[:social_security_number])
        @social_insurance_number_fields = @user.company.custom_fields.where(field_type: CustomField.field_types[:social_insurance_number])
        @emergency_phone_fields = @user.company.custom_fields.where('name ILIKE ? AND field_type = ?', '%Emergency%', CustomField.field_types[:short_text]).where.not('name ILIKE ?', '%Email%')
        @emergency_email_fields = @user.company.custom_fields.where('name ILIKE ? AND field_type = ?', '%Emergency%', CustomField.field_types[:short_text]).where('name ILIKE ?', '%Email%')
        
        @address_custom_fields.try(:each) do |address_custom_field|
          address_custom_field.sub_custom_fields.try(:each) do |sub_custom_field|
            create(:custom_field_value, sub_custom_field_id: sub_custom_field.id, user_id: @user.id, value_text: 'abc')
          end
        end

        @simple_phone_custom_fields.try(:each) do |simple_phone_custom_field|
          create(:custom_field_value, custom_field_id: simple_phone_custom_field.id, user_id: @user.id, value_text: '123-11223344')
        end

        @social_security_number_fields.try(:each) do |social_security_number_field|
          create(:custom_field_value, custom_field_id: social_security_number_field.id, user_id: @user.id, value_text: '122334421')
        end

        @social_insurance_number_fields.try(:each) do |social_insurance_number_field|
          create(:custom_field_value, custom_field_id: social_insurance_number_field.id, user_id: @user.id, value_text: '112233449')
        end

        @emergency_phone_fields.try(:each) do |emergency_phone_field|
          create(:custom_field_value, custom_field_id: emergency_phone_field.id, user_id: @user.id, value_text: '112233441')
        end

        @emergency_email_fields.try(:each) do |emergency_email_field|
          create(:custom_field_value, custom_field_id: emergency_email_field.id, user_id: @user.id, value_text: 'abx@xyzsasas.com')
        end

        GdprService::GdprManagement.new(@user).perform
        @user.reload
      end

      context 'anonymize user table data' do
        it 'should anonymize user first name' do
          expect(@user.first_name).to eq('Anonymized')
        end
        
        it 'should anonymize user preferred name' do
          expect(@user.preferred_name).to eq('Anonymized')
        end
        
        it 'should anonymize state' do
          expect(@user.state).to eq('inactive')
        end
        
        it 'should anonymize preferred full name' do
          expect(@user.preferred_full_name).to eq('Anonymized')
        end
        
        it 'should anonymize bamboo_id ' do
          expect(@user.bamboo_id).to eq(nil)
        end
        
        it 'should anonymize namely_id' do
          expect(@user.namely_id).to eq(nil)
        end
        
        it 'should anonymize adp_wfn_us_id' do
          expect(@user.adp_wfn_us_id).to eq(nil)
        end

        it 'should anonymize adp_wfn_can_id' do
          expect(@user.adp_wfn_can_id).to eq(nil)
        end
        
        it 'should anonymize okta_id' do
          expect(@user.okta_id).to eq(nil)
        end
        
        it 'should anonymize one_login_id' do
          expect(@user.one_login_id).to eq(nil)
        end

        it 'should create anonymize datum of user' do
          expect(@user.anonymized_datum.present?).to eq(true)
        end
      end

      context 'anonymize custom fields data' do
        it 'should anonymize address field' do
          @address_custom_fields.try(:each) do |address_custom_field|
            expect(@user.get_custom_field_value_text(nil, true, nil, address_custom_field)[:line1]).to eq('123 City Street')
            expect(@user.get_custom_field_value_text(nil, true, nil, address_custom_field)[:line2]).to eq('123 City Street')
            expect(@user.get_custom_field_value_text(nil, true, nil, address_custom_field)[:city]).to eq('San Francisco, California')
            expect(@user.get_custom_field_value_text(nil, true, nil, address_custom_field)[:state]).to eq('CA')
            expect(@user.get_custom_field_value_text(nil, true, nil, address_custom_field)[:zip]).to eq('94100')
          end
        end
        
        it 'should anonymize simple phone field' do
          @simple_phone_custom_fields.try(:each) do |simple_phone_custom_field|
            expect(@user.get_custom_field_value_text(nil, true, nil, simple_phone_custom_field)).to eq('000-00000000')
          end
        end

        it 'should anonymize international phone field' do
          value = @user.get_custom_field_value_text(nil, true, nil, @phone_field_with_value)
          expect(value[:area_code]).to eq("000")
          expect(value[:country]).to eq("PAK")
          expect(value[:phone]).to eq("0000000")
        end

        it 'should anonymize social security number' do
          @social_security_number_fields.try(:each) do |social_security_number_field|
            expect(@user.get_custom_field_value_text(nil, true, nil, social_security_number_field)).to eq('000000000')
          end
        end

        it 'should anonymize social insurance number' do
          @social_insurance_number_fields.try(:each) do |social_insurance_number_field|
            expect(@user.get_custom_field_value_text(nil, true, nil, social_insurance_number_field)).to eq('000000000')
          end
        end
        
        it 'should anonymize emergency field' do
          @emergency_phone_fields.try(:each) do |emergency_phone_field|
            expect(@user.get_custom_field_value_text(nil, true, nil, emergency_phone_field)).to eq('Anonymized')
          end

          @emergency_email_fields.try(:each) do |emergency_email_field|
            expect(@user.get_custom_field_value_text(nil, true, nil, emergency_email_field)).to eq('Anonymized')
          end
        end
      end
    end

    context 'should delete data for departed user if GDPR not applied yet' do
      before(:all) do
        @user = create(:departed_user_with_no_gdpr, termination_date: 400.days.ago, gdpr_action_date: 1.day.ago, company: create(:company, subdomain: 'GDPR-SERVICES-2'))
        create(:general_data_protection_regulation, action_type: GeneralDataProtectionRegulation.action_types[:remove], company: @user.company)
        
        GdprService::GdprManagement.new(@user).perform
      end

      it 'it should delete user and set deletion through gdpr to true' do
        expect(@user.deleted_at.present?).to eq(true)
        expect(@user.deletion_through_gdpr).to eq(true)
      end
    end
  end
end