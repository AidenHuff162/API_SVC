require 'rails_helper'

RSpec.describe PaperworkPacketConnection, type: :model do
  
  describe 'column specifications' do
    it { is_expected.to have_db_column(:connectable_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:paperwork_packet_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime).with_options(presence: true, null: false) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime).with_options(presence: true, null: false) }
    it { is_expected.to have_db_column(:deleted_at).of_type(:datetime).with_options(presence: true) }
    it { is_expected.to have_db_column(:connectable_type).of_type(:string).with_options(presence: true) }

    it { is_expected.to have_db_index(:connectable_id) }
    it { is_expected.to have_db_index([:connectable_type, :connectable_id]) }
    it { is_expected.to have_db_index(:deleted_at) }
    it { is_expected.to have_db_index(:paperwork_packet_id) }

  end

  describe 'Associations' do
    it { is_expected.to belong_to(:connectable)}
    it { is_expected.to belong_to(:paperwork_packet)}
  end
end

