require 'rails_helper'

RSpec.describe State, type: :model do
	
	describe 'associations' do
		it { is_expected.to belong_to(:country) }
	end

	describe 'column specifications' do
		it { is_expected.to have_db_column(:key).of_type(:string) }
		it { is_expected.to have_db_column(:name).of_type(:string) }
		it { is_expected.to have_db_column(:country_id).of_type(:integer) }

		it { is_expected.to have_db_index(:country_id) }
	end
end