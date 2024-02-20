require 'rails_helper'

RSpec.describe CustomSection, type: :model do
  
  describe 'column specifications' do
    it { is_expected.to have_db_column(:section).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:company_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime).with_options(presence: true, null: false) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime).with_options(presence: true, null: false) }
    it { is_expected.to have_db_column(:is_approval_required).of_type(:boolean).with_options(presence: true, default: false) }
    it { is_expected.to have_db_column(:approval_expiry_time).of_type(:integer).with_options(presence: true) }

    it { is_expected.to have_db_index(:company_id) }
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:company)}
    it { is_expected.to have_many(:custom_fields)}
    it { is_expected.to have_many(:approval_chains).dependent(:destroy)}
  end

  describe 'Nested Attributes' do
    it { should accept_nested_attributes_for(:approval_chains).allow_destroy(true) }
  end

  describe 'Enums' do
    it { should define_enum_for(:section).with([:profile, :personal_info, :private_info, :additional_fields]) }
  end

end

