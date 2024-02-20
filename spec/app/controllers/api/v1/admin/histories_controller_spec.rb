require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe Api::V1::Admin::HistoriesController, type: :controller do
	let(:company) { create(:company) }
	let(:sarah) { create(:sarah, company: company) }

	before do
		allow(controller).to receive(:current_company).and_return(company)
		allow(controller).to receive(:current_user).and_return(sarah)
	end
	describe 'index' do
		context 'unauthenticated user' do
			before do
				allow(controller).to receive(:current_user).and_return(nil)
			end
			it 'should return 204 status' do
				get :index, params: { per_page: 20, page: 1, sub_tab: 'dashboard' }, format: :json
				expect(response.status).to eq(204)
			end
		end
		context 'authenticated user' do
			let(:nick){ create(:nick, company: company) }
			before do
				100.times { create(:history, company: company, user: nick)}
			end
			context 'with term' do
				before do
					get :index, params: { term: "#{History.first.description.split(" ").first}", per_page: 20, page: 1, sub_tab: 'dashboard' }, format: :json
				end
				it 'should return histories matching search term' do
					expect(JSON.parse(response.body)["histories"]).to_not eq(nil)
				end
				it 'should return histories for company' do
					expect(JSON.parse(response.body)["histories"].map{|h| h["company"]["id"]}.uniq.join(",").to_i)
					.to eq(company.id)
				end
				context 'with empty search term' do
					it 'should return 20 histories' do
						get :index, params: { term: "", per_page: 20, page: 1, sub_tab: 'dashboard' }, format: :json
						expect(JSON.parse(response.body)["histories"].size).to eq(20)
					end
				end
			end
			context 'with out search term' do
				context 'for first page' do
					before do
						get :index, params: { per_page: 20, page: 1, sub_tab: 'dashboard' }, format: :json
					end
					it 'should fetch histories for first page' do
						expect(JSON.parse(response.body)["histories"].size).to eq(20)
					end
					it 'should return with a status of 200' do
						expect(response.status).to eq(200)
					end
					it 'should return data in descending order' do
						expect(JSON.parse(response.body)["histories"].first["id"]).to eq(History.last.id)
					end
				end
			end
			context 'for second page' do
				before do
					get :index, params: { per_page: 20, page: 2 }, format: :json
				end
				it 'should fetch histories for first page' do
					expect(JSON.parse(response.body)["histories"].size).to eq(20)
				end
				it 'should return with a status of 200' do
					expect(response.status).to eq(200)
				end
				it 'should return data in descending order' do
					expect(JSON.parse(response.body)["histories"].first["id"]).to eq(History.last.id - 20)
				end
			end
			context 'without permissions' do
				context 'with no_access' do
					before do
						user_role = sarah.user_role
						user_role.permissions['admin_visibility']['dashboard'] = 'no_access'
						user_role.save
						get :index, params: { per_page: 20, page: 1, sub_tab: 'dashboard' }, format: :json
					end
					it 'should return response of 204' do
						expect(response.status).to eq(204)
					end
				end
				context 'user accessing index' do
					before do
						allow(controller).to receive(:current_user).and_return(nick)
						get :index, params: { per_page: 20, page: 1, sub_tab: 'dashboard' }, format: :json
					end
					it 'should return response of 204' do
						expect(response.status).to eq(204)
					end
				end
			end
		end
	end
	describe 'remaining controller methods' do
		let(:nick){ create(:nick, company: company) }
		before do
			UserEmail.create(user: nick, invite_at: (Date.today + 7.days).strftime("%Y-%m-%d %H:%M"), email_status: 0, email_type: 'welcome_email')
		end
		let!(:history){ create(:history, company: company, user: nick, created_by: 'system', email_type: 'welcome', event_type: 'scheduled_email',
			 user_email_id: nick.user_emails.first.id,
			 schedule_email_at: (Date.today + 7.days).strftime("%Y-%m-%d %H:%M"),
			 description: "Welcome Email for #{nick.full_name}")}
		let!(:history_user){ create(:history_user, user: nick, history: history)}
		context 'delete_scheduled_email' do
			context 'for unauthenticated user' do
				before do
					allow(controller).to receive(:current_user).and_return(nil)
					post :delete_scheduled_email, params: { id: history.id }, format: :json
				end
				it 'should not delete the scheduled_email' do
					expect(nick.user_emails.first.email_status).to_not eq(UserEmail.statuses[:deleted])
				end
				it 'should not have nil in scheduled_email_at' do
					expect(history.reload.schedule_email_at).to_not eq(nil)
				end
				it 'should keep history event_type to scheduled' do
					expect(history.reload.event_type).to eq('scheduled_email')
				end
				it 'should not create a new history' do
					expect(History.count).to eq(1)
				end
			end
			context 'for authenticated user' do
				before do
					post :delete_scheduled_email, params: { id: history.id }, format: :json
				end
				it 'should delete the scheduled_email' do
					expect(nick.user_emails.first.email_status).to eq(UserEmail.statuses[:deleted])
				end
				it 'should have nil in scheduled_email_at' do
					expect(history.reload.schedule_email_at).to eq(nil)
				end
				it 'should set history event_type to email' do
					expect(history.reload.event_type).to eq('email')
				end
				it 'should create a new history' do
					expect(History.count).to eq(2)
				end
				it 'should create new history with appropriate description' do
					expect(History.last.description).to eq("Welcome Email for #{nick.full_name} has been deleted.")
				end
				it 'should create a new history with a history_user' do
					expect(History.last.history_users.size).to eq(1)
				end
				it 'should create a new history with a history_user as nick' do
					expect(History.last.history_users.first.user_id).to eq(nick.id)
				end
			end
		end
		context 'update_scheduled_email' do
			context 'for unauthenticated user' do
				before do
					allow(controller).to receive(:current_user).and_return(nil)
					post :update_scheduled_email, params: { id: history.id, schedule_email_at: "#{(Date.today + 10.days).strftime("%Y-%m-%d")}T22:00:00.000Z" }, format: :json
				end
				it 'should not reschedule user_email' do
					expect(nick.user_emails.first.email_status).to eq(0)
				end
				it 'should not change date for user_email' do
					expect(nick.user_emails.first.invite_at.to_date).to eq(Date.today + 7.days)
				end
				it 'should not create another history' do
						expect(History.count).to eq(1)
					end
			end
			context 'for authenticated user' do
				context 'for welcome email' do
					before do
						post :update_scheduled_email, params: { id: history.id, schedule_email_at: "#{(Date.today + 10.days).strftime("%Y-%m-%d")}T22:00:00.000Z" }, format: :json
					end
					it 'should reschedule user_email' do
						expect(nick.user_emails.first.email_status).to eq(1)
					end
					it 'should set new date of user_email for the email' do
						expect(nick.user_emails.first.invite_at.to_date).to eq(Date.today + 10.days)
					end
					it 'should set new time of user_email for the email' do
						time = (nick.user_emails.first.invite_at).strftime("%H%M%S")
						expect(time).to eq("220000")
					end
					it 'should create another history with accurate description' do
						expect(History.last.description).to include("Welcome Email scheduled for #{nick.full_name}")
					end
					it 'should create a new history with a history_user' do
						expect(History.last.history_users.size).to eq(1)
					end
					it 'should create a new history with a history_user as nick' do
						expect(History.last.history_users.first.user_id).to eq(nick.id)
					end
				end
				context 'for invite email' do
					let(:user_email) { create(:user_email, user: nick) }
					let(:invite){ create(:invite, user_email: user_email)}
					before do
						UserMailer.delay_until("#{Date.today + 10.days}").onboarding_email(invite)
						@job_id = Sidekiq::Extensions::DelayedMailer.jobs.first["jid"]
						history.update_columns(email_type: 2, job_id: @job_id)
						invite.update_column(:job_id, @job_id)
						post :update_scheduled_email, params: { id: history.id, schedule_email_at: "#{(Date.today + 10.days).strftime("%Y-%m-%d")}T22:00:00.000Z" }, format: :json
					end
					it 'should create a new history with status scheduled_email' do
						expect(History.last.event_type).to eq('scheduled_email')
					end
					it 'should create a new history with job_id' do
						expect(History.last.job_id).to eq(@job_id)
					end
					it 'should create a new history for nick' do
						expect(History.last.user_id).to eq(nick.id)
					end
					it 'should create a new history with a history_user' do
						expect(History.last.history_users.size).to eq(1)
					end
					it 'should create a new history with a history_user as nick' do
						expect(History.last.history_users.first.user_id).to eq(nick.id)
					end
				end
			end
		end
	end
end
