require 'rails_helper'

RSpec.describe DocumentConnectionRelation, type: :model do
  subject(:document_connection_relation) {FactoryGirl.create(:document_connection_relation)}

  describe 'Associations' do
    it { is_expected.to have_many(:user_document_connections) }
    it { is_expected.to have_many(:users) }
    it { is_expected.to have_one(:document_upload_request) }
  end
end
