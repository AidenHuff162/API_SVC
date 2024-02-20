require 'rails_helper'

RSpec.describe Interactions::AdminUsers::DeactivateExpiredUsers do
  let!(:admin_user) {create(:admin_user)}
  describe 'deactivate admin user' do
    it 'should expire user if expire date is of today' do
      Interactions::AdminUsers::DeactivateExpiredUsers.new.perform
      expect(admin_user.reload.state).to eq('inactive')
    end

    it 'should expire user if expire date is of past' do
      admin_user.update(expiry_date: Date.today - 2.days)
      Interactions::AdminUsers::DeactivateExpiredUsers.new.perform
      expect(admin_user.reload.state).to eq('inactive')
    end

    it 'should not expire user if expire date is of future' do
      admin_user.update(expiry_date: Date.today + 2.days)
      Interactions::AdminUsers::DeactivateExpiredUsers.new.perform
      expect(admin_user.reload.state).to_not eq('inactive')
    end
  end
end
