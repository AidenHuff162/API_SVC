require 'rails_helper'

RSpec.describe Api::V1::CalendarFeedsController, type: :controller do
  let(:company){ create(:company, enabled_time_off: true) }
  let(:nick_with_cf){ create(:user, :with_calendar_feed, title: 'Sander', company: company, role: User.roles["employee"]) }
  let(:nick){ create(:nick, company: company) }
  let(:company2){ create(:company, subdomain: 'c2') }
  let(:company2_user_with_cf){ create(:user, :with_calendar_feed, company: company2, role: User.roles["employee"]) }

  before do
  	allow(controller).to receive(:current_user).and_return(nick)
  	allow(controller).to receive(:current_company).and_return(company)
  end

  describe 'index' do
    context 'accessed by unauthenticated_user' do
    	before do
    		allow(controller).to receive(:current_user).and_return(nil)
      end
      it 'should return unauth response' do
      	get :index, params: { user_id: nick.id }, format: :json
      	expect(response.status).to eq(401)
      end
    end

    context 'accessed by authenticated_user' do
    	before do
    		get :index, params: { user_id: nick_with_cf.id }, format: :json
    	end
    	it 'should return 200 status' do
    		expect(response.status).to eq(200)
    	end
    	it 'should return calendar feed' do
    		expect(JSON.parse(response.body).size).to eq(1)
    	end
    	it 'should return calendar feed for that particular user' do
    		expect(JSON.parse(response.body).first['user_id']).to eq(nick_with_cf.id)
    	end
    end
  end

  describe 'create' do
  	context 'accessed by unauthenticated_user' do
  		before do
  			allow(controller).to receive(:current_user).and_return(nil)
  		end
  		it 'should return unauth response' do
  			post :create, params: { user_id: nick.id, feed_type: 'overdue_activity' }, format: :json
  			expect(response.status).to eq(401)
  		end
  	end
  	context 'accessed by authenticated_user' do
  		before do
  			post :create, params: { user_id: nick.id, feed_type: 'overdue_activity' }, format: :json
  		end

  		it 'should return a response of 201' do
  			expect(response.status).to eq(201)
  		end

  		it 'should add a new calendar feed to user' do
  			expect(nick.reload.calendar_feeds.size).to eq(1)
  		end

  		it 'should create a calendar_feed of type overdue_activity' do
  			expect(nick.calendar_feeds.first.feed_type).to eq('overdue_activity')
  		end
  	end
  end

  describe 'update' do
  	context 'accessed by unauthenticated_user' do
  		before do
  			allow(controller).to receive(:current_user).and_return(nil)
  		end
  		it 'should return unauth response' do
  			calendar_feed = nick_with_cf.calendar_feeds.first
  			put :update, params: { user_id: nick_with_cf.id, feed_url: calendar_feed.feed_url, feed_type: calendar_feed.feed_type, feed_id: calendar_feed.feed_id, id: calendar_feed.id }, format: :json
  			expect(response.status).to eq(401)
  		end
  	end
  	context 'accessed by authenticated_user' do
  		before do
  			allow(controller).to receive(:current_user).and_return(nick_with_cf)
  			@calendar_feed = nick_with_cf.calendar_feeds.first
  			put :update, params: { user_id: nick_with_cf.id, feed_url: @calendar_feed.feed_url, feed_type: @calendar_feed.feed_type, feed_id: @calendar_feed.feed_id, id: @calendar_feed.id }, format: :json
  		end
  		it 'should update the feed' do
  			expect(response.status).to eq(200)
  		end
  		it 'should regenerate caledar feed url' do
  			expect(@calendar_feed.feed_url).to_not eq(nick_with_cf.reload.calendar_feeds.first.feed_url)
  		end
  		it 'should regenerate calendar_feed id' do
  			expect(@calendar_feed.feed_id).to_not eq(nick_with_cf.reload.calendar_feeds.first.feed_id)
  		end
  		it 'should not generate an additional calendar_feed for the same type' do
  			expect(nick_with_cf.calendar_feeds.where(feed_type: CalendarFeed.feed_types[@calendar_feed.feed_type]).size).to eq(1)
  		end
  		it 'should not change the feed_type of the calendar_feed' do
  			expect(@calendar_feed.feed_type).to eq(nick_with_cf.calendar_feeds.first.feed_type)
  		end
   	end
  end

  describe 'destroy' do
  	context 'accessed by an unauthenticated_user' do
  		before do
  			allow(controller).to receive(:current_user).and_return(nil)
  		end
  		it 'should return unauth response' do
  			delete :destroy, params: { id: nick_with_cf.calendar_feeds.first.id }, format: :json
  			expect(response.status).to eq(401)
  		end
  	end
  	context 'accessed by an authenticated_user' do
  		before do
  			allow(controller).to receive(:current_user).and_return(nick_with_cf)
  			delete :destroy, params: { id: nick_with_cf.calendar_feeds.first.id }, format: :json
  		end
  		it 'should respond with code 204' do
  			expect(response.status).to eq(204)
  		end
  		it 'should remove calendar_feed' do
  			expect(nick_with_cf.reload.calendar_feeds.size).to eq(0)
  		end
  	end
  end

  describe 'feed' do
  	context 'for overdue_activity' do
  		let(:workstream){ create(:workstream, company: company )}
  		let(:task){ create(:task, workstream: workstream )}
  		before do
  			feed = nick_with_cf.calendar_feeds.first
  			feed.update_column(:feed_type, 2)
  			@task_user_connection = create(:task_user_connection, task: task, user: nick_with_cf, owner: nick_with_cf, due_date: Date.today - 10.days)
  			get :feed, params: { id: nick_with_cf.calendar_feeds.first.feed_id }, format: :json
  		end
  		it 'should return calendar_feed with correct summary' do
  			expect(response.body.gsub(/\s+/, ' ').strip).to include("SUMMARY:#{task.name} for #{nick_with_cf.display_name} (#{nick_with_cf.title}" )
  		end
  		it 'should return calendar_feed with correct begin date' do
  			expect(response.body.gsub(/\s+/, ' ').strip).to include("DTSTART;VALUE=DATE:#{@task_user_connection.due_date.strftime('%Y%m%d')}")
  		end
  	end
  	context 'start_date' do
  		before do
  			feed = nick_with_cf.calendar_feeds.first
  			feed.update_column(:feed_type, 0)
  			get :feed, params: { id: nick_with_cf.calendar_feeds.first.feed_id }, format: :json
  		end
  		it 'should return calendar_feed with correct summary' do
  			expect(response.body.gsub(/\s+/, ' ').strip).to include("SUMMARY:#{nick_with_cf.name_with_title}'s First Day!")
  		end
  		it 'should return calendar_feed with corret description' do
  			expect(response.body.gsub(/\s+/, ' ').strip).to include("DESCRIPTION:Give them a warm welcome!")
  		end
  		it 'should return calendar_feed for correct start date' do
  			expect(response.body.gsub(/\s+/, ' ').strip).to include("DTSTART;VALUE=DATE:#{nick_with_cf.start_date.strftime('%Y%m%d')}")
  		end
  	end
  	context 'birthday' do
  		before do
  			company.calendar_permissions = {}
  			company.calendar_permissions["anniversary"] = true
  			company.calendar_permissions["birthday"] = true
  			company.save
  			feed = nick_with_cf.calendar_feeds.first
  			feed.update_column(:feed_type, 1)
  			cf = nick_with_cf.company.custom_fields.find_by_name('Date of Birth') rescue nil
  			@dob = "10-10-1980"
  			custom_field_value = create(:custom_field_value, custom_field: cf, user: nick_with_cf, value_text: @dob)
  			get :feed, params: { id: nick_with_cf.calendar_feeds.first.feed_id }, format: :json
  		end

  		it 'should return calendar_feed with correct summary' do
  			expect(response.body.gsub(/\s+/, ' ').strip).to include("SUMMARY:#{nick_with_cf.name_with_title}'s Birthday")
  		end
  		it 'should return calendar_feed with correct description' do
  			expect(response.body.gsub(/\s+/, ' ').strip).to include("DESCRIPTION:Wish them a Happy Birthday!")
  		end
  		it 'should return calendar_feed with correct start_date' do
  			@dob.to_date
  			expect(response.body.gsub(/\s+/, ' ').strip).to include("DTSTART;VALUE=DATE:#{Date.today.year}#{@dob.to_date.month}#{@dob.to_date.day}")
  		end
  	end
  	context 'offboarding_date' do
  		before do
  			feed = nick_with_cf.calendar_feeds.first
  			feed.update_column(:feed_type, 3)
  			nick_with_cf.update_columns(current_stage: User.current_stages[:last_month], termination_date: Date.today + 2.days, last_day_worked: Date.today)
  			get :feed, params: { id: nick_with_cf.calendar_feeds.first.feed_id }, format: :json
  		end
  		it 'should return calendar_feed with correct summary' do
  			expect(response.body.gsub(/\s+/, ' ').strip).to include("SUMMARY:#{nick_with_cf.display_name} (#{nick_with_cf.title}")
  		end
  		it 'should return calendar_feed with correct description' do
  			expect(response.body.gsub(/\s+/, ' ').strip).to include("DESCRIPTION:Final Day for #{nick_with_cf.display_name} (")
  		end
  		it 'should return calendar_feed with correct start_date' do
  			expect(response.body.gsub(/\s+/, ' ').strip).to include("DTSTART;VALUE=DATE:#{nick_with_cf.termination_date.strftime('%Y%m%d')}")
  		end
  	end
  	context 'anniversary' do
  		before do
  			company.calendar_permissions = {}
  			company.calendar_permissions["anniversary"] = true
  			company.calendar_permissions["birthday"] = true
  			company.save
  			feed = nick_with_cf.calendar_feeds.first
  			feed.update_column(:feed_type, 4)
  			get :feed, params: { id: nick_with_cf.calendar_feeds.first.feed_id }, format: :json
  		end
  		it 'should return calendar_feed with correct summary' do
  			expect(response.body.gsub(/\s+/, ' ').strip).to include("SUMMARY:#{nick_with_cf.name_with_title}'s Six month")
  		end
  		it 'should return calendar_feed with correct description' do
  			expect(response.body.gsub(/\s+/, ' ').strip).to include("DESCRIPTION:Show them your appreciation!")
  		end
  		it 'should return calendar_feed with correct start_date' do
  			six_month_anniversary = nick_with_cf.start_date + 6.months
  			expect(response.body.gsub(/\s+/, ' ').strip).to include("DTSTART;VALUE=DATE:#{six_month_anniversary.strftime('%Y%m%d')}")
  		end
  		context 'start date greater than six months' do
				before do
					feed = nick_with_cf.calendar_feeds.first
					feed.update_column(:feed_type, 4)
					nick_with_cf.update_column(:start_date, Date.today - 1.years)
					get :feed, params: { id: nick_with_cf.calendar_feeds.first.feed_id }, format: :json
	  		end
	  		it 'should return calendar_feed with correct summary' do
	  			expect(response.body.gsub(/\s+/, ' ').strip).to include("SUMMARY:#{nick_with_cf.name_with_title}'s")
	  		end
	  		it 'should return calendar_feed with correct description' do
	  			expect(response.body.gsub(/\s+/, ' ').strip).to include("DESCRIPTION:Show them your appreciation!")
	  		end
	  		it 'should return calendar_feed with correct start_date' do
	  			six_month_anniversary = nick_with_cf.start_date + 1.years
	  			expect(response.body.gsub(/\s+/, ' ').strip).to include("DTSTART;VALUE=DATE:#{six_month_anniversary.strftime('%Y%m%d')}")
	  		end
  		end
  	end
  	context 'out_of_office' do
  		let(:pto_policy){ create(:default_pto_policy, company: company)}
  		before do
			allow_any_instance_of(Company).to receive(:calendar_feed_syncing_feature_flag).and_return(true)
  			feed = nick_with_cf.calendar_feeds.first
  			feed.update_column(:feed_type, 5)
        User.current = nick_with_cf
        nick_with_cf.update_column(:start_date, nick_with_cf.start_date - 1.year)
        @pto_request = create(:pto_request, partial_day_included: false, pto_policy: pto_policy, user: nick_with_cf, begin_date: Date.today + 2.days, end_date: Date.today + 2.days, status: 1)
        nick_with_cf.company.update!(enabled_time_off: true)
  			get :feed, params: { id: nick_with_cf.calendar_feeds.first.feed_id }, format: :json
  		end
  		it 'should return calendar_feed with correct summary' do
  			expect(response.body.gsub(/\s+/, ' ').strip).to include("SUMMARY:#{nick_with_cf.name_with_title} - #{pto_policy.name}")
  		end
  		it 'should return calendar_feed with correct description' do
  			expect(response.body.gsub(/\s+/, ' ').strip).to include("DESCRIPTION:Time Off for #{nick_with_cf.display_name}")
  		end
  		it 'should return calendar_feed with correct start_date' do
  			expect(response.body.gsub(/\s+/, ' ').strip).to include("DTSTART;VALUE=DATE:#{@pto_request.begin_date.strftime('%Y%m%d')}")
  		end
  	end
  end

  describe 'authorisation' do
    context 'authorisation check' do
    	context 'for user belonging to different company' do
    		before do
    			@ability = Ability.new(company2_user_with_cf)
    		end
    		it 'should not allow to read a calendar feed of another company' do
      		assert @ability.cannot?(:read, nick_with_cf.calendar_feeds.first)
      	end
      	it 'should not allow to update a calendar feed of another company' do
      		assert @ability.cannot?(:update, nick_with_cf.calendar_feeds.first)
      	end
      	it 'should not allow to create a calendar feed of another company' do
      		assert @ability.cannot?(:create, nick_with_cf.calendar_feeds.first)
      	end
      	it 'should not allow to destroy a calendar feed of another company' do
      		assert @ability.cannot?(:destroy, nick_with_cf.calendar_feeds.first)
      	end
    	end
    	context 'for user belonging to same company' do
    		before do
    			@ability = Ability.new(nick_with_cf)
    		end
    		it 'should allow user to read a calendar feed' do
      		assert @ability.can?(:read, nick_with_cf.calendar_feeds.first)
      	end
      	it 'should allow user to update a calendar feed' do
      		assert @ability.can?(:update, nick_with_cf.calendar_feeds.first)
      	end
      	it 'should allow user to create a calendar feed' do
      		assert @ability.can?(:create, nick_with_cf.calendar_feeds.first)
      	end
      	it 'should allow user to destroy a calendar feed' do
      		assert @ability.can?(:destroy, nick_with_cf.calendar_feeds.first)
      	end
    	end
    	context 'for user who is manager but in company2' do
    		before do
    			nick = create(:nick, email: 'nicktest@mail.com', personal_email: 'nicktestuser@mail.com', company: company2)
    			manager = nick.manager
    			@ability = Ability.new(manager)
    		end
    		it 'should not be able to read calendar feed of user from different company' do
    			assert @ability.cannot?(:read, nick_with_cf.calendar_feeds.first)
    		end
    		it 'should not be able to update calendar feed of user from different company' do
    			assert @ability.cannot?(:update, nick_with_cf.calendar_feeds.first)
    		end
    		it 'should not be able to destroy calendar feed of user from different company' do
    			assert @ability.cannot?(:create, nick_with_cf.calendar_feeds.first)
    		end
    		it 'should not be able to create calendar feed of user from different company' do
    			assert @ability.cannot?(:destroy, nick_with_cf.calendar_feeds.first)
    		end
    	end
    	context 'for user who is manager in company' do
    		before do
    			manager = nick.manager
    			calendar_feed = create(:calendar_feed, company: company, user: nick, feed_type: 1)
    			@ability = Ability.new(manager)
    		end
    		it 'should allow to create calendar feed for managed user' do
    			assert @ability.can?(:create, CalendarFeed.new(user: nick))
    		end
    		it 'should allow to update calendar feed for managed user' do
    			assert @ability.can?(:update, nick.calendar_feeds.first)
    		end
    		it 'should allow to destroy calendar feed for managed user' do
    			assert @ability.can?(:destroy, nick.calendar_feeds.first)
    		end
    		it 'should allow to read calendar feed for managed user' do
    			assert @ability.can?(:read, nick.calendar_feeds.first)
    		end
    	end
    	context 'for user who is not a manager but is in the same company' do
    		before do
    			manager = nick.manager
    			@ability = Ability.new(manager)
    		end
    		it 'should not allow to create calendar feed for managed user' do
    			assert @ability.cannot?(:create, CalendarFeed.new(user: nick_with_cf))
    		end
    		it 'should not allow to update calendar feed for managed user' do
    			assert @ability.cannot?(:update, nick_with_cf.calendar_feeds.first)
    		end
    		it 'should not allow to destroy calendar feed for managed user' do
    			assert @ability.cannot?(:destroy, nick_with_cf.calendar_feeds.first)
    		end
    		it 'should not allow to read calendar feed for managed user' do
    			assert @ability.cannot?(:read, nick_with_cf.calendar_feeds.first)
    		end
    	end
    end
  end

end
