require 'rails_helper'

RSpec.describe Interactions::Users::RemoveExpiredGhostUsers do
  let!(:user) {create(:user, expires_in: Date.today - 2.days)}
  before { stub_request(:delete, "https://hufpez22n1.algolia.net/1/indexes/User_/#{user.id}").to_return(status: 200, body: "", headers: {}) }
  describe 'expire ghost user' do
    it "should  destroy the user" do
      Interactions::Users::RemoveExpiredGhostUsers.new.perform
      expect(user.reload.deleted_at).to_not eq(nil)
    end

    it "should not destroy the user if expires_in is nil" do
      user.update_column(:expires_in, nil)
      Interactions::Users::RemoveExpiredGhostUsers.new.perform
      expect(user.reload.deleted_at).to eq(nil)
    end

    it "should not destroy the user if expires_in is of future" do
      user.update_column(:expires_in, Date.today + 10.days)
      Interactions::Users::RemoveExpiredGhostUsers.new.perform
      expect(user.reload.deleted_at).to eq(nil)
    end
  end
end
