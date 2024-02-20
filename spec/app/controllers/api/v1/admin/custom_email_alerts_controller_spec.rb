require 'rails_helper'

RSpec.describe Api::V1::Admin::CustomEmailAlertsController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:valid_session) { {} }

  before do
    # sign_in user
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "POST #create" do
  	context 'unauthenticated user' do
  		before do
  			allow(controller).to receive(:current_user).and_return(nil)
  		end
  		it 'should respond with a 401 status' do
  			post :create, params: { alert_type: CustomEmailAlert.alert_types[:timeoff_approved], title: 'TimeOff Approved', subject: 'TimeOff Approved',
	        body: 'Time has been approved', edited_by_id: user.id }, as: :json
	      expect(response.status).to eq(401)
  		end
  	end
  	context 'authenticated user' do
	    it "should create custom alert for time-off approved with all locations, departments and statuses" do
	      post :create, params: { alert_type: CustomEmailAlert.alert_types[:timeoff_approved], title: 'TimeOff Approved', subject: 'TimeOff Approved',
	        body: 'Time has been approved', edited_by_id: user.id }, as: :json
	      expect(response.message).to eq('Created')
	    end

	    it "should create custom alert for time-off requested with all locations, departments and statuses" do
	      post :create, params: { alert_type: CustomEmailAlert.alert_types[:timeoff_requested], title: 'TimeOff Requested', subject: 'TimeOff Requested',
	        body: 'Time has been requested', edited_by_id: user.id }, as: :json
	      expect(response.message).to eq('Created')
	      expect(JSON.parse(response.body).keys).to eq(['id', 'title', 'subject', 'applied_to_teams', 'applied_to_locations', 'applied_to_statuses', 'updated_at', 'edited_by', 'is_enabled'])
	    end

	    it "should create custom alert for time-off denied with all locations, departments and statuses" do
	      post :create, params: { alert_type: CustomEmailAlert.alert_types[:timeoff_denied], title: 'TimeOff Denied', subject: 'TimeOff Denied',
	        body: 'Time has been denied', edited_by_id: user.id }, as: :json
	      expect(response.message).to eq('Created')
	    end

	    it "should create custom alert for time-off canceled with all locations, departments and statuses" do
	      post :create, params: { alert_type: CustomEmailAlert.alert_types[:timeoff_canceled], title: 'TimeOff Canceled', subject: 'TimeOff Canceled',
	        body: 'Time has been canceled', edited_by_id: user.id }, as: :json
	      expect(response.message).to eq('Created')
	    end

	    it "should create custom alert for time-off approved with all locations, departments but selected statuses" do
	      post :create, params: { alert_type: CustomEmailAlert.alert_types[:timeoff_approved], title: 'TimeOff Approved', subject: 'TimeOff Approved',
	        body: 'Time has been approved', edited_by_id: user.id, applied_to_statuses: ['Full Time'] }, as: :json
	      expect(response.message).to eq('Created')
	    end

	    it "should create custom alert for time-off approved with all locations, statuses but selected departments" do
	      post :create, params: { alert_type: CustomEmailAlert.alert_types[:timeoff_approved], title: 'TimeOff Approved', subject: 'TimeOff Approved',
	        body: 'Time has been approved', edited_by_id: user.id, applied_to_departments: ['1', '2'] }, as: :json
	      expect(response.message).to eq('Created')
	    end

	    it "should create custom alert for time-off approved with all departments, statuses but selected locations" do
	      post :create, params: { alert_type: CustomEmailAlert.alert_types[:timeoff_approved], title: 'TimeOff Approved', subject: 'TimeOff Approved',
	        body: 'Time has been approved', edited_by_id: user.id, applied_to_locations: ['1'] }, as: :json
	      expect(response.message).to eq('Created')
	    end
	  end
  end

  describe 'GET #index' do
  	context 'for unauthenticated user' do
  		before do
  			allow(controller).to receive(:current_user).and_return(nil)
  		end
  		it 'should return a response of 401' do
  			get :index, as: :json
  			expect(response.status).to eq(401)
  		end
  	end
  	context 'authenticated user' do
  		before do
  			3.times do
  				create(:custom_email_alert, company: company)
  			end
  		end
  		it 'should return requested data' do
  			get :index, as: :json
  			expect(response.status).to eq(200)
  			expect(JSON.parse(response.body).size).to eq(3)
  			expect(JSON.parse(response.body).first.keys).to eq(['id', 'title', 'subject', 'applied_to_teams', 'applied_to_locations', 'applied_to_statuses', 'updated_at', 'edited_by', 'is_enabled'])
  		end
  	end
  end

  describe "DELETE #destroy" do
  	let!(:alert){ create(:custom_email_alert, company: company) }
  	context 'unauthenticated user' do
  		before do
  			allow(controller).to receive(:current_user).and_return(nil)
  		end
  		it 'should return 401 status' do
  			delete :destroy, params: { id: alert.id }, as: :json
  			expect(response.status).to eq(401)
  		end
  	end
  	context 'authenticated user' do
  		it 'should delete the alert' do
  			delete :destroy, params: { id: alert.id }, as: :json
  			expect(response.status).to eq(201)
  			expect(CustomEmailAlert.all.size).to eq(8)
  		end
  	end
  end

  describe 'PUT #send_test_alert' do
  	let!(:alert){ create(:custom_email_alert, company: company) }
  	context 'unauthenticated user' do
  		before do
  			allow(controller).to receive(:current_user).and_return(nil)
  		end
  		it 'should return response of 401' do
  			put :send_test_alert, params: { id: alert.id, title: alert.title, subject: alert.subject,
	  		applied_to_teams: alert.applied_to_teams, applied_to_locations: alert.applied_to_locations,
	  		applied_to_statuses: alert.applied_to_statuses, alert_type: alert.alert_type,
	  		notified_to: alert.notified_to, notifiers: alert.notifiers, body: alert.body },
	  		as: :json
  			expect(response.status).to eq(401)
  		end
  	end
  	context 'authenticated user' do
  		it 'should send test_email' do
  			expect {
					put :send_test_alert, params: { id: alert.id, title: alert.title, subject: alert.subject,
		  		applied_to_teams: alert.applied_to_teams, applied_to_locations: alert.applied_to_locations,
		  		applied_to_statuses: alert.applied_to_statuses, alert_type: alert.alert_type,
		  		notified_to: alert.notified_to, notifiers: alert.notifiers, body: alert.body },
		  		as: :json
	  		}.to change { CompanyEmail.count }.by(1)
  		end
  	end
  end

  describe 'GET #show' do
  	let!(:alert){ create(:custom_email_alert, company: company) }
  	context 'unauthenticated user' do
  		before do
  			allow(controller).to receive(:current_user).and_return(nil)
  		end
  		it 'should return 401 status' do
  			get :show, params: { id: alert.id }, as: :json
  			expect(response.status).to eq(401)
  		end
  	end
  	context 'authenticated user' do
  		it 'should return alert' do
  			get :show, params: { id: alert.id }, as: :json
  			expect(response.status).to eq(200)
  			expect(JSON.parse(response.body)['id']).to eq(alert.id)
  			expect(JSON.parse(response.body).keys).to eq(['id', 'title', 'subject', 'applied_to_teams',
  			'applied_to_locations', 'applied_to_statuses', 'updated_at',
      	'alert_type', 'notified_to', 'individuals', 'notifiers', 'body'])
  		end
  	end
  end

  describe "PUT #update" do
  	context 'unauthenticated user' do
  		before do
  			allow(controller).to receive(:current_user).and_return(nil)
  		end
  		it 'should return a response of 401' do
  			custom_alert = FactoryGirl.create(:custom_email_alert, company: user.company, edited_by_id: user.id)
	      put :update, params: { id: custom_alert.id, alert_type: CustomEmailAlert.alert_types[:timeoff_denied] }, as: :json
	      expect(response.status).to eq(401)
  		end
  	end
	  context 'authenticated user' do
	    it "should update default alert type to denied" do
	      custom_alert = FactoryGirl.create(:custom_email_alert, company: user.company, edited_by_id: user.id)
	      put :update, params: { id: custom_alert.id, alert_type: CustomEmailAlert.alert_types[:timeoff_denied] }, as: :json
	      custom_alert.reload
	      expect(custom_alert.alert_type).to eq('timeoff_denied')
	      expect(response.status).to eq(200)
	    end

	    it "should update default notified to to individual" do
	      custom_alert = FactoryGirl.create(:custom_email_alert, company: user.company, edited_by_id: user.id)
	      put :update, params: { id: custom_alert.id, notified_to: 'individual' }, as: :json
	      custom_alert.reload
	      expect(custom_alert.notified_to).to eq('individual')
	      expect(response.status).to eq(200)
	      expect(JSON.parse(response.body).keys).to eq(['id', 'title', 'subject', 'applied_to_teams', 'applied_to_locations', 'applied_to_statuses', 'updated_at', 'edited_by', 'is_enabled'])
	    end
	  end
  end
end
