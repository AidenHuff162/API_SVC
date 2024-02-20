require 'rails_helper'

RSpec.describe CompanyLink, type: :model do
  let(:company) { create(:company) }

  describe '#associations' do
    it { should belong_to(:company) }
  end

end
