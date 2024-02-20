require 'rails_helper'

RSpec.describe PaperworkPacket, type: :model do
  it { is_expected.to have_many(:paperwork_packet_connections) }
  it { is_expected.to have_many(:paperwork_requests) }
  it { is_expected.to belong_to(:company).class_name('Company') }
  it { is_expected.to belong_to(:user).class_name('User') }

  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:template) { create(:paperwork_template, :template_skips_validate, company: company, user: user) }
  let(:packet) { create(:paperwork_packet, company: company) }
  let(:connection) { create(:paperwork_packet_connection, connectable: template, paperwork_packet: packet) }


  describe 'Update PaperworkPacket' do
    it 'will create paperwork_packet_connection' do
      expect(connection).to be_valid
      expect(packet.paperwork_packet_connections.count).to eq 1
    end

    it 'will return empty documents if flag not enabled' do
      expect(packet.documents).to eq []
    end
  end
end
