require 'rails_helper'
require 'cancan/matchers'

RSpec.describe CustomEmailAlert, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to(:company)}
    it { is_expected.to belong_to(:edited_by).class_name('User') }
  end
  describe 'ability' do
		let(:sarah){ create(:sarah, company: company) }
		let(:peter){ create(:peter, company: company) }
  	let(:company){ create(:company) }
  	context 'should manage' do
	  	context 'if user is account_owner' do
	  		subject(:ability) { Ability.new(sarah) }
				it{ should be_able_to(:manage, CustomEmailAlert.new(company: company)) }
	  	end
	  	context 'if user is admin' do
	  		subject(:ability) { Ability.new(peter) }
	  		it{ should be_able_to(:manage, CustomEmailAlert.new(company: company)) }
	  	end
  	end
  	context 'should not manage' do
			let(:nick){ create(:nick, company: company) }
			let(:second_company){ create(:company) }
			let(:alert){ create(:custom_email_alert, company: second_company) }
  		context 'if user is employee' do
  			subject(:ability) { Ability.new(nick) }
  			it{ should_not be_able_to(:manage, CustomEmailAlert.new(company: company)) }
  			it{ should_not be_able_to(:read, CustomEmailAlert.new(company: company)) }
  			it{ should_not be_able_to(:destroy, CustomEmailAlert.new(company: company)) }
  		end
  		context 'if nick accesses alert of different company' do
  			subject(:ability) { Ability.new(nick) }
  			it{ should_not be_able_to(:manage, alert) }
  		end
  		context 'if sarah accesses alert of different company' do
  			subject(:ability) { Ability.new(sarah) }
  			it{ should_not be_able_to(:manage, alert) }
  		end
  		context ' if peter accesses alert of different company' do
  			subject(:ability) { Ability.new(peter) }
  			it{ should_not be_able_to(:manage, alert) }
  		end
  	end
  end	
end
