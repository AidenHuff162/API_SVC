require 'rails_helper'

RSpec.describe SftpForm, type: :model do
  describe 'Validation' do
    describe 'Name' do
      it { is_expected.to validate_presence_of(:name) }
    end

    describe 'authentication_key_type' do
      it { is_expected.to validate_presence_of(:authentication_key_type) }
    end

    describe 'host_url' do
      it { is_expected.to validate_presence_of(:host_url) }
    end

    describe 'user_name' do
      it { is_expected.to validate_presence_of(:user_name) }
    end

    describe 'port' do
      it { is_expected.to validate_presence_of(:port) }
    end

    describe 'folder' do
      it { is_expected.to validate_presence_of(:folder_path) }
    end

    describe 'updated_by_id' do
      it { is_expected.to validate_presence_of(:updated_by_id) }
    end

    describe 'company_id' do
     it { is_expected.to validate_presence_of(:company_id) }
    end
  end
end
