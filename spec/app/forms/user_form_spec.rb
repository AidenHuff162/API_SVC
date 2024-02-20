require 'rails_helper'

RSpec.describe UserForm, type: :model do
  subject(:form) { UserForm.new(attributes_for(:user)) }

  describe 'Validation' do
    describe 'First name' do
      it { is_expected.to validate_presence_of(:first_name) }
    end

    describe 'Last name' do
      it { is_expected.to validate_presence_of(:last_name) }
    end

    describe 'Email' do
      it { is_expected.to allow_value(Faker::Internet.email).for(:email) }
      it { is_expected.not_to allow_value(Faker::Lorem.word).for(:email) }

      it 'is not allowed to create with same email case insensitively scoped to company' do
        user = create(:user)
        form = UserForm.new(
          attributes_for(:user, company_id: user.company_id, email: user.email.upcase)
        )

        expect { form.save! }.to raise_error(ActiveRecord::RecordInvalid , /Email addresses must be unique, please try again/)

      end
    end

    describe 'Personal email' do
      it { is_expected.to allow_value(Faker::Internet.email).for(:personal_email) }
      it { is_expected.not_to allow_value(Faker::Lorem.word).for(:personal_email) }

      it 'is not allowed to create with same personal email case insensitively scoped to company' do
        user = create(:user)
        form = UserForm.new(
          attributes_for(:user, company_id: user.company_id, personal_email: user.personal_email.upcase)
        )

        expect { form.save! }.to raise_error(ActiveRecord::RecordInvalid , /Email addresses must be unique, please try again/)

      end
    end

    describe 'Start date' do
      it { is_expected.to validate_presence_of(:start_date) }

      it 'not allows dates before today' do
        form.start_date = 1.day.ago.to_date
        is_expected.not_to be_valid
      end

      it 'not allows bad dates' do
        form.start_date = 'Hello'
        is_expected.not_to be_valid
      end
    end

    describe 'Company' do
      it { is_expected.to validate_presence_of(:company_id) }
    end
  end
end
