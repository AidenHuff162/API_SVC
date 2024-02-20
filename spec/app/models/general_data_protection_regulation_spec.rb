require 'rails_helper'

RSpec.describe GeneralDataProtectionRegulation, type: :model do

  let(:company) { FactoryGirl.create(:company) }

  describe 'associations' do
    it { is_expected.to belong_to(:company) }
  end

  describe 'column specification' do
    describe 'Action type' do
      it { is_expected.to have_db_column(:action_type).of_type(:integer).with_options(presence: true) }
    end

    describe 'Action period' do
      it { is_expected.to have_db_column(:action_period).of_type(:integer).with_options(presence: true) }
    end

    describe 'Action location' do
      it { is_expected.to have_db_column(:action_location).of_type(:string).with_options(presence: true) }
    end

    describe 'Edited by id' do
      it { is_expected.to have_db_column(:edited_by_id).of_type(:integer).with_options(presence: true) }
    end

    describe 'Company id' do
      it { is_expected.to have_db_column(:company_id).of_type(:integer).with_options(presence: true) }
    end
  end

  describe 'validations' do
    it { should validate_inclusion_of(:action_period).in_range(1..7) }

    subject { GeneralDataProtectionRegulation.new(company_id: company.id) }
    it { is_expected.to validate_uniqueness_of(:company_id) }

    it 'should give validation error if action period is nil' do
      expect { create(:general_data_protection_regulation, company: company, action_period: nil) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Action period is not included in the list')
    end
  end

  describe 'enums' do
    it { should define_enum_for(:action_type).with([:anonymize, :remove]) }
  end

  describe 'callbacks' do
    context 'before save' do
      it 'should remove blank element from action location' do
        general_data_protection_regulation = FactoryGirl.create(:general_data_protection_regulation, company: company, 
          action_location: ['', nil, '1', '2'])
        expect(general_data_protection_regulation.action_location).to eq(['1', '2'])
      end
    end

    context 'after create' do
      let(:sample_company) { create(:company_with_random_users, subdomain: 'boo') }
      
      context 'enforce GDPR after one year on terminated users' do
        before do
          @general_data_protection_regulation = FactoryGirl.create(:general_data_protection_regulation, company: sample_company, action_location: ['all'])
        end

        it 'should be enforced on all terminated users except previously applied ones' do
          terminated_users = sample_company.users.where(is_gdpr_action_taken: false, current_stage: User.current_stages[:departed])
          expect(terminated_users.pluck(:gdpr_action_date)).to eq(terminated_users.pluck(:termination_date).map { |td| (td+@general_data_protection_regulation.action_period.year) })
        end

        it 'should not be enforced on all previously applied terminated users' do
          terminated_users = sample_company.users.where(is_gdpr_action_taken: true, current_stage: User.current_stages[:departed])
          expect(terminated_users.pluck(:gdpr_action_date)).not_to eq(terminated_users.pluck(:termination_date).map { |td| (td+@general_data_protection_regulation.action_period.year) })
        end

        it 'should not be enforced on non terminated users' do
          non_terminated_users = sample_company.users.where.not(current_stage: User.current_stages[:departed])
          expect(non_terminated_users.pluck(:gdpr_action_date).reject(&:blank?)).to eq([])
        end
      end

      context 'enforce GDPR after five year on terminated users' do
        before do
          @general_data_protection_regulation = FactoryGirl.create(:general_data_protection_regulation, company: sample_company, action_location: ['all'], action_period: 5)
        end

        it 'should be enforced on all terminated users except previously applied ones' do
          terminated_users = sample_company.users.where(is_gdpr_action_taken: false, current_stage: User.current_stages[:departed])
          expect(terminated_users.pluck(:gdpr_action_date)).to eq(terminated_users.pluck(:termination_date).map { |td| (td+@general_data_protection_regulation.action_period.year) })
        end

        it 'should not be enforced on all previously applied terminated users' do
          terminated_users = sample_company.users.where(is_gdpr_action_taken: true, current_stage: User.current_stages[:departed])
          expect(terminated_users.pluck(:gdpr_action_date)).not_to eq(terminated_users.pluck(:termination_date).map { |td| (td+@general_data_protection_regulation.action_period.year) })
        end

        it 'should not be enforced on non terminated users' do
          non_terminated_users = sample_company.users.where.not(current_stage: User.current_stages[:departed])
          expect(non_terminated_users.pluck(:gdpr_action_date).reject(&:blank?)).to eq([])
        end
      end

      context 'enforce GDPR after four year on london based terminated users' do
        before do
          @london = sample_company.locations.where(name: 'London').take
          @general_data_protection_regulation = FactoryGirl.create(:general_data_protection_regulation, company: sample_company, action_location: [@london.id.to_s], 
            action_period: 4)
        end

        it 'should be enforced on all london based terminated users except previously applied ones' do
          terminated_users = sample_company.users.where(is_gdpr_action_taken: false, current_stage: User.current_stages[:departed], location_id: @london.id)
          expect(terminated_users.pluck(:gdpr_action_date)).to eq(terminated_users.pluck(:termination_date).map { |td| (td+@general_data_protection_regulation.action_period.year) })
        end

        it 'should not be enforced on all non london based terminated users except previously applied ones' do
          terminated_users = sample_company.users.where(is_gdpr_action_taken: false, current_stage: User.current_stages[:departed]).where.not(location_id: @london.id)
          expect(terminated_users.pluck(:gdpr_action_date).reject(&:blank?)).to eq([])
        end

        it 'should not be enforced on all previously applied terminated users' do
          terminated_users = sample_company.users.where(is_gdpr_action_taken: true, current_stage: User.current_stages[:departed])
          expect(terminated_users.pluck(:gdpr_action_date)).not_to eq(terminated_users.pluck(:termination_date).map { |td| (td+@general_data_protection_regulation.action_period.year) })
        end

        it 'should not be enforced on non terminated users' do
          non_terminated_users = sample_company.users.where.not(current_stage: User.current_stages[:departed])
          expect(non_terminated_users.pluck(:gdpr_action_date).reject(&:blank?)).to eq([])
        end
      end

      context 'enforce GDPR after three year on san fransisco based terminated users' do
        before do
          @san_fransisco = sample_company.locations.where(name: 'San Fransisco').take
          @general_data_protection_regulation = FactoryGirl.create(:general_data_protection_regulation, company: sample_company, action_location: [@san_fransisco.id.to_s], 
            action_period: 3)
        end

        it 'should be enforced on all san fransisco based terminated users except previously applied ones' do
          terminated_users = sample_company.users.where(is_gdpr_action_taken: false, current_stage: User.current_stages[:departed], location_id: @san_fransisco.id)
          expect(terminated_users.pluck(:gdpr_action_date)).to eq(terminated_users.pluck(:termination_date).map { |td| (td+@general_data_protection_regulation.action_period.year) })
        end

        it 'should not be enforced on all non san fransisco based terminated users except previously applied ones' do
          terminated_users = sample_company.users.where(is_gdpr_action_taken: false, current_stage: User.current_stages[:departed]).where.not(location_id: @san_fransisco.id)
          expect(terminated_users.pluck(:gdpr_action_date).reject(&:blank?)).to eq([])
        end

        it 'should not be enforced on all previously applied terminated users' do
          terminated_users = sample_company.users.where(is_gdpr_action_taken: true, current_stage: User.current_stages[:departed])
          expect(terminated_users.pluck(:gdpr_action_date)).not_to eq(terminated_users.pluck(:termination_date).map { |td| (td+@general_data_protection_regulation.action_period.year) })
        end

        it 'should not be enforced on non terminated users' do
          non_terminated_users = sample_company.users.where.not(current_stage: User.current_stages[:departed])
          expect(non_terminated_users.pluck(:gdpr_action_date).reject(&:blank?)).to eq([])
        end
      end

      context 'enforce GDPR after two year on san fransisco/london based terminated users' do
        before do
          @locations = sample_company.locations.where(name: ['San Fransisco', 'London']).pluck(:id)
          @general_data_protection_regulation = FactoryGirl.create(:general_data_protection_regulation, company: sample_company, action_location: [@locations.map(&:to_s)], 
            action_period: 2)
        end

        it 'should be enforced on all san fransisco/london based terminated users except previously applied ones' do
          terminated_users = sample_company.users.where(is_gdpr_action_taken: false, current_stage: User.current_stages[:departed], location_id: @locations)
          expect(terminated_users.pluck(:gdpr_action_date)).to eq(terminated_users.pluck(:termination_date).map { |td| (td+@general_data_protection_regulation.action_period.year) })
        end

        it 'should not be enforced on all non san fransisco/london based terminated users except previously applied ones' do
          terminated_users = sample_company.users.where(is_gdpr_action_taken: false, current_stage: User.current_stages[:departed]).where.not(location_id: @locations)
          expect(terminated_users.pluck(:gdpr_action_date).reject(&:blank?)).to eq([])
        end

        it 'should not be enforced on all previously applied terminated users' do
          terminated_users = sample_company.users.where(is_gdpr_action_taken: true, current_stage: User.current_stages[:departed])
          expect(terminated_users.pluck(:gdpr_action_date)).not_to eq(terminated_users.pluck(:termination_date).map { |td| (td+@general_data_protection_regulation.action_period.year) })
        end

        it 'should not be enforced on non terminated users' do
          non_terminated_users = sample_company.users.where.not(current_stage: User.current_stages[:departed])
          expect(non_terminated_users.pluck(:gdpr_action_date).reject(&:blank?)).to eq([])
        end

        it 'imposed gdpr on selected action location' do
          expect(sample_company.locations.where(is_gdpr_imposed: true).count).to eq(@locations.count)
        end
      end
    end

    context 'after update' do
      let(:sample_company) { create(:company_with_random_users, subdomain: 'boo') }

      context 'update enforced GDPR on terminated users on action period/location change' do
        before do
          @general_data_protection_regulation = FactoryGirl.create(:general_data_protection_regulation, company: sample_company, action_location: ['all'])

          @london = sample_company.locations.where(name: 'London').take
          @new_york = sample_company.locations.where(name: 'New York').take
        end
        
        it 'should update enforced GDPR after two year on all the terminated users, if GDPR not applied yet' do
          @general_data_protection_regulation.update!(action_period: 2)
          terminated_users = sample_company.users.where(is_gdpr_action_taken: false, current_stage: User.current_stages[:departed])
          expect(terminated_users.pluck(:gdpr_action_date)).to eq(terminated_users.pluck(:termination_date).map { |td| (td+2.year) })
        end

        it 'should update enforced GDPR after three year on all the london based terminated users, if GDPR not applied yet' do
          @general_data_protection_regulation.update!(action_period: 3, action_location: [@london.id.to_s])

          terminated_users = sample_company.users.where(is_gdpr_action_taken: false, current_stage: User.current_stages[:departed], location_id: @london.id)
          expect(terminated_users.pluck(:gdpr_action_date)).to eq(terminated_users.pluck(:termination_date).map { |td| (td+3.year) })
        end

        it 'should update enforced GDPR date to blank on all the non london based terminated users, if GDPR not applied yet' do
          @general_data_protection_regulation.update!(action_period: 3, action_location: [@london.id.to_s])

          terminated_users = sample_company.users.where(is_gdpr_action_taken: false, current_stage: User.current_stages[:departed]).where.not(location_id: @london.id)
          expect(terminated_users.pluck(:gdpr_action_date).reject(&:blank?)).to eq([])
        end

        it 'should update enforced GDPR after six year on all the london/newyork based terminated users, if GDPR not applied yet' do
          @general_data_protection_regulation.update!(action_period: 6, action_location: [@london.id.to_s, @new_york.id.to_s])

          terminated_users = sample_company.users.where(is_gdpr_action_taken: false, current_stage: User.current_stages[:departed], location_id: [@london.id, @new_york.id])
          expect(terminated_users.pluck(:gdpr_action_date)).to eq(terminated_users.pluck(:termination_date).map { |td| (td+6.year) })
        end

        it 'should update enforced GDPR date to blank on all the non london/newyork based terminated users, if GDPR not applied yet, if GDPR not applied yet' do
          @general_data_protection_regulation.update!(action_period: 6, action_location: [@london.id.to_s, @new_york.id.to_s])

          terminated_users = sample_company.users.where(is_gdpr_action_taken: false, current_stage: User.current_stages[:departed]).where.not(location_id: [@london.id, @new_york.id])
          expect(terminated_users.pluck(:gdpr_action_date).reject(&:blank?)).to eq([])
        end

        it 'should not update enforced GDPR, if GDPR is already applied on terminated users' do
          @general_data_protection_regulation.update!(action_period: 3, action_location: [@london.id.to_s, @new_york.id.to_s])

          terminated_users = sample_company.users.where(is_gdpr_action_taken: true, current_stage: User.current_stages[:departed])
          expect(terminated_users.pluck(:gdpr_action_date)).not_to eq(terminated_users.pluck(:termination_date).map { |td| (td+3.year) })
        end
      end
    end
  end
  
end
