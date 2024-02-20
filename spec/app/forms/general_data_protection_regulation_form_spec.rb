require 'rails_helper'

RSpec.describe GeneralDataProtectionRegulationForm, type: :model do

  describe 'Validation' do
    describe 'Action type' do
      it { is_expected.to validate_presence_of(:action_type) }
    end

    describe 'Action period' do
      it { is_expected.to validate_presence_of(:action_period) }
    end

    describe 'Edited by id' do
      it { is_expected.to validate_presence_of(:edited_by_id) }
    end

    describe 'Company id' do
      it { is_expected.to validate_presence_of(:company_id) }
    end
  end
end
