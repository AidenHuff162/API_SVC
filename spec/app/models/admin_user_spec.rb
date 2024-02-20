require 'rails_helper'

RSpec.describe AdminUser, type: :model do

   describe 'column specifications' do
    it { is_expected.to have_db_column(:email).of_type(:string).with_options(presence: true, null: false, default: '') }
    it { is_expected.to have_db_column(:encrypted_password).of_type(:string).with_options(presence: true, null: false, default: '') }
    it { is_expected.to have_db_column(:reset_password_token).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:reset_password_sent_at).of_type(:datetime).with_options(presence: true) }
    it { is_expected.to have_db_column(:remember_created_at).of_type(:datetime).with_options(presence: true) }
    it { is_expected.to have_db_column(:sign_in_count).of_type(:integer).with_options(presence: true, default: 0, null: false) }
    it { is_expected.to have_db_column(:current_sign_in_at).of_type(:datetime).with_options(presence: true) }
    it { is_expected.to have_db_column(:last_sign_in_at).of_type(:datetime).with_options(presence: true) }
    it { is_expected.to have_db_column(:current_sign_in_ip).of_type(:inet).with_options(presence: true) }
    it { is_expected.to have_db_column(:last_sign_in_ip).of_type(:inet).with_options(presence: true) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime).with_options(presence: true, null: false) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime).with_options(presence: true, null: false) }
    it { is_expected.to have_db_column(:encrypted_otp_secret).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:encrypted_otp_secret_iv).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:encrypted_otp_secret_salt).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:consumed_timestep).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:otp_required_for_login).of_type(:boolean).with_options(presence: true) }
    it { is_expected.to have_db_column(:expiry_date).of_type(:date).with_options(presence: true) }
    it { is_expected.to have_db_column(:state).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:first_login).of_type(:boolean).with_options(presence: true, default: true) }
    it { is_expected.to have_db_column(:access_token).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:email_verification_token).of_type(:string).with_options(presence: true) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:active_admin_loggings) }
  end

  describe 'callbacks' do
    it { is_expected.to callback(:enable_two_factor_authentication).after(:create) }
    it { is_expected.to callback(:enable_two_factor_authentication).after(:update) }
    it { is_expected.to callback(:send_email_to_admin_user).after(:create) }
    it { is_expected.to callback(:update_first_login_as_false).after(:save) }
    it { is_expected.to callback(:update_first_login_as_false).after(:save) }
    it { is_expected.to callback(:generate_token_for_authentication).before(:create) }
    context 'after_create' do
      context 'enable_two_factor_authentication' do
        let!(:admin_user) {create(:admin_user)}
        it 'should enable_two_factor_authentication' do
          expect(admin_user.otp_required_for_login).to eq(true)
          expect(admin_user.otp_secret).to_not eq(nil)
          expect(admin_user.first_login).to eq(true)
          expect(admin_user.after_state_change).to eq(true)
        end
      end

      context 'send_email_to_admin_user' do
        let(:admin_user) {create(:admin_user)}
        it 'should send_email_to_admin_user' do
          expect{admin_user}.to change{CompanyEmail.count}.by(1)
        end
      end

      context 'enable_two_factor_authentication' do
        let(:admin_user) {create(:admin_user)}
        it 'should enable_two_factor_authentication' do
          expect{admin_user}.to change{CompanyEmail.count}.by(1)
        end
      end
    end

    context 'after_update' do
      context 'enable_two_factor_authentication' do
        let!(:admin_user) {create(:admin_user)}
        it 'should enable_two_factor_authentication' do
          admin_user.update(state: 'inactive', otp_required_for_login: false, otp_secret: nil, first_login: false, after_state_change: false)
          admin_user.update(state: 'active')
          expect(admin_user.otp_required_for_login).to eq(true)
          expect(admin_user.otp_secret).to_not eq(nil)
          expect(admin_user.first_login).to eq(true)
        end

        it 'should not enable_two_factor_authentication' do
          admin_user.update(state: 'inactive', otp_required_for_login: false, otp_secret: nil, first_login: false, after_state_change: false)
          admin_user.update(state: 'active', after_state_change: true)
          expect(admin_user.otp_required_for_login).to_not eq(true)
          expect(admin_user.otp_secret).to eq(nil)
          expect(admin_user.first_login).to_not eq(true)
        end
      end
    end

    context 'after_save' do
      context 'update_first_login_as_false' do
        let!(:admin_user) {create(:admin_user)}
        it 'should update_first_login_as_false' do
          admin_user.update(sign_in_count: 2)
          expect(admin_user.first_login).to eq(false)
        end

        it 'should not update_first_login_as_false' do
          admin_user.update(state: 'active')
          expect(admin_user.first_login).to eq(true)
        end
      end

      context 'update_first_login_as_true' do
        let!(:admin_user) {create(:admin_user)}
        it 'should update_first_login_as_true' do
          admin_user.update(otp_required_for_login: false)
          admin_user.update(otp_required_for_login: true)
          expect(admin_user.first_login).to eq(true)
        end

        it 'should not update_first_login_as_true' do
          admin_user.update(otp_required_for_login: false, first_login: false)
          expect(admin_user.first_login).to eq(false)
        end
      end
    end

    context 'before_create' do
      let!(:admin_user) {create(:admin_user)}
      it 'should generate_token_for_authentication' do
        expect(admin_user.email_verification_token).to_not eq(nil)
      end
    end

  end
end
