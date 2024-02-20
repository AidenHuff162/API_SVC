require 'rails_helper'
require "cancan/matchers"

RSpec.describe Api::V1::Admin::CalendarFeedsController, type: :controller do
	let(:company){ create(:company) }
	let(:nick_with_cf) { create(:user, :with_calendar_feed, company: company) }
	let(:sarah) { create(:sarah, company: company) }
	let(:company2){ create(:company, subdomain: 'baar') }

	before do
		allow(controller).to receive(:current_user).and_return(sarah)
		allow(controller).to receive(:current_company).and_return(company)
	end

	describe 'authorisation' do
		context 'sarah accessing feed of different company' do
			let(:sarah2) { create(:sarah, email: 'sarah@testasd.com', personal_email: 'sarahsalem@mail.com', company: company2) }
			subject(:ability) { Ability.new(sarah2) }
			it{ should_not be_able_to(:manage, nick_with_cf.calendar_feeds.first) }
		end
		context 'sarah accessing feed of same company' do
			subject(:ability) { Ability.new(sarah) }
			it{should be_able_to(:manage, nick_with_cf.calendar_feeds.first) }
		end
		context 'admin accessing feed of different company' do
			let(:peter){ create(:peter, company: company2) }
			subject(:ability){ Ability.new(peter) }
			it{ should_not be_able_to(:manage, nick_with_cf.calendar_feeds.first) }
		end
		context 'admin accessing feed of same company' do
			let(:peter){ create(:peter, company: company) }
			subject(:ability){ Ability.new(peter) }
			it{ should be_able_to(:manage, nick_with_cf.calendar_feeds.first) }
		end
		context 'employee access feed of different company' do
			let(:nick2){ create(:nick, company: company2) }
			subject(:ability) { Ability.new(nick2) }
			it{ should_not be_able_to(:manage, nick_with_cf.calendar_feeds.first) }
		end
		context 'employee accessing someone elses calendar feed inside same company' do
			let(:nick){ create(:nick, company: company)}
			subject(:ability) { Ability.new(nick) }
			it{ should_not be_able_to(:manage, nick_with_cf.calendar_feeds.first) }
		end
		context 'employee accessing their own calendar_feed' do
			subject(:ability) { Ability.new(nick_with_cf) }
			it{ should be_able_to(:manage, nick_with_cf.calendar_feeds.first) }
		end
	end
	describe 'index' do
		context 'unauthenticated user' do
			before do
				allow(controller).to receive(:current_user).and_return(nil)
			end
			it 'should return 401 response' do
				get :index, params: { user_id: sarah.id }, format: :json
				expect(response.status).to eq(401)
			end
		end
		context 'authenticated user' do
			before do
				get :index, params: { user_id: nick_with_cf.id }, format: :json
			end
			it 'should return a response of 200' do
				expect(response.status).to eq(200)
			end
			it 'should return calendar_feeds' do
				expect(JSON.parse(response.body).size).to eq(1)
			end
			it 'should return calendar_feeds for the specific user' do
				expect(JSON.parse(response.body).first["user_id"]).to eq(nick_with_cf.id)
			end
		end
	end
	describe 'create' do
		context 'unauthenticated user' do
			before do
				allow(controller).to receive(:current_user).and_return(nil)
			end
			it 'should return 401 status' do
				post :create, params: { user_id: nick_with_cf.id, feed_type: 'overdue_activity' }, format: :json
  			expect(response.status).to eq(401)
			end
		end
		context 'authenticated user' do
			let(:nick){ create(:nick, company: company) }
			before do
				post :create, params: { user_id: nick.id, feed_type: 'overdue_activity' }, format: :json
			end
			it 'should create calendar_feed' do
				expect(response.status).to eq(201)
			end
			it 'should increase the number of calendar_feeds for nick' do
				expect(nick.reload.calendar_feeds.size).to eq(1)
			end
		end
		context 'creating for with a duplicate feed_type' do
			let!(:nick){ create(:user, :with_calendar_feed, company: company)}
			it 'should throw validation error' do
				post :create, params: { user_id: nick.id, feed_type: nick.calendar_feeds.first.feed_type }, format: :json
				expect(response.status).to eq(422)
			end
		end
	end
	describe 'update' do
		context 'unauthenticated user' do
			before do
				allow(controller).to receive(:current_user).and_return(nil)
			end
			it 'should return 401 status' do
				calendar_feed = nick_with_cf.calendar_feeds.first
				put :update, params: { user_id: nick_with_cf.id, feed_url: calendar_feed.feed_url, feed_type: calendar_feed.feed_type, feed_id: calendar_feed.feed_id, id: calendar_feed.id }, format: :json
				expect(response.status).to eq(401)
			end
		end
		context 'authenticated user' do
			before do
				@calendar_feed = nick_with_cf.calendar_feeds.first
				put :update, params: { user_id: nick_with_cf.id, feed_url: @calendar_feed.feed_url, feed_type: @calendar_feed.feed_type, feed_id: @calendar_feed.feed_id, id: @calendar_feed.id }, format: :json
			end
			it 'should return status of 200' do
				expect(response.status).to eq(200)
			end
			it 'should not duplicate the calendar_feed for nick_with_cf' do
				expect(nick_with_cf.reload.calendar_feeds.size).to eq(1)
			end
			it 'should not change the calendar_feed_type' do
				expect(nick_with_cf.reload.calendar_feeds.first.feed_type).to eq(@calendar_feed.feed_type)
			end
		end
	end
	describe 'destroy' do
		context 'unauthenticated user' do
			before do
				allow(controller).to receive(:current_user).and_return(nil)
			end
			it 'should return 401 status' do
				delete :destroy, params: { id: nick_with_cf.calendar_feeds.first.id }, format: :json
  			expect(response.status).to eq(401)
			end
		end
		context 'authenticated user' do
			before do
				delete :destroy, params: { id: nick_with_cf.calendar_feeds.first.id }, format: :json
			end
			it 'should return a response of 204' do
				expect(response.status).to eq(204)
			end
			it 'should remove respective users calendar_feed' do
				expect(nick_with_cf.calendar_feeds.size).to eq(0)
			end
		end
	end
end
