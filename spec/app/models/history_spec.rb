require 'rails_helper'
require 'cancan/matchers'

RSpec.describe History, type: :model do
  describe 'associations' do
  	it{should belong_to(:user)}
  	it{should belong_to(:company)}
  	it{should have_many(:history_users).dependent(:destroy)}
  end
  describe 'validations' do
  	it{should validate_presence_of(:company_id)}
  	it{should validate_presence_of(:description)}
  end
  describe 'authorisations' do
  	let(:company){ create(:company) }
  	let(:nick){ create(:nick, company: company) }
  	let(:peter){ create(:peter, company: company) }
  	let(:sarah){ create(:sarah, company: company) }
  	let(:history){ create(:history, company: company, user: nick)}
  	context 'for employee' do
  		subject(:ability) { Ability.new(nick) }
  		it{should_not be_able_to(:manage, history)}
  	end
  	context 'for admin' do
  		subject(:ability) { Ability.new(peter) }
  		it{should be_able_to(:manage, history)}
  	end
  	context 'for owner' do
  		subject(:ability) { Ability.new(sarah) }
  		it{should be_able_to(:manage, history)}
  	end
  	context 'for user of different company' do
  		let(:company2){ create(:company, subdomain: 'history-company')}
  		let(:nick2){ create(:user, company: company2 )}
  		let(:new_history){ create(:history, company: company2, user: nick2)}
  		subject(:ability) { Ability.new(sarah) }
  		it{should_not be_able_to(:manage, new_history)}
  	end
  end	
end
