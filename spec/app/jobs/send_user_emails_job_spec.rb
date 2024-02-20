require 'rails_helper'

RSpec.describe SendUserEmailsJob, type: :job do
  let!(:company) {create(:company, notifications_enabled: true, preboarding_complete_emails: true, enabled_time_off: true)}
  let!(:peter) {create(:peter, current_stage: :registered, role: "employee", title: "Software Engineer", company: company, start_date: Date.today)}
  let!(:custom_field) {create(:custom_field, :date_of_birth, company: company)}
  let!(:custom_field_value) {create(:custom_field_value, user: peter, custom_field: custom_field, value_text: "#{30.years.ago}")}

	describe 'user emails for onboarding' do
		let!(:immediate_user_email) {create(:user_email, user: peter, email_type: :invitation, email_status: UserEmail::statuses[:incomplete], schedule_options: {send_email: 0})}
	  let!(:custome_date_user_email) {create(:user_email, user: peter, email_type: :invitation, email_status: UserEmail::statuses[:incomplete], schedule_options: {date: Date.today, time: Time.now + 1.hour, send_email: 1})}
	  let!(:relative_start_date_user_email) {create(:user_email, user: peter, email_type: :invitation, email_status: UserEmail::statuses[:incomplete], schedule_options: {duration: 30, send_email: 2, relative_key: "start date", duration_type: "days", due: "after"})}
	  let!(:relative_dob_user_email) {create(:user_email, user: peter, email_type: :invitation, email_status: UserEmail::statuses[:incomplete], schedule_options: {duration: 60, send_email: 2, relative_key: "birthday", duration_type: "days", due: "after"})}

		# context 'should not send user emails' do
		#   it 'should not send emails when user is not present' do
		#   	SendUserEmailsJob.perform_now(nil, 'onboarding')
	    #   expect(Sidekiq::Queues["schedule_email"].size).to eq(0)
		#   end

		#   it 'should not send emails and destroy all incomplete emails when send is false' do
	    #   expect(peter.user_emails.length).to eq(4)
		#   	SendUserEmailsJob.perform_now(peter.id, 'onboarding', false)
		#   	peter.user_emails.reload
	    #   expect(peter.user_emails.length).to eq(0)
		#   end
		#end

		context 'should send user emails for onboarding' do
			it 'should update email_status to completed	or scheduled wrt email' do
				peter.user_emails.try(:each) do |user_email|
				  user_email.invite_at = Inbox::SetInviteAt.new.set_invite_at(user_email)
				  user_email.setup_recipients(peter.personal_email)
				  user_email.save!
				end

		  	SendUserEmailsJob.perform_now(peter.id, 'onboarding', true)
		  	peter.user_emails.reload
		  	scheduled = UserEmail::statuses[:scheduled]
		  	completed = UserEmail::statuses[:completed]
			email_status = peter.user_emails.pluck(:email_status)
			expect(peter.user_emails.length).to eq(4)
		  	expect(email_status.include?(completed)).to eq(true)
			end

			it 'should create a invite for user' do
		  	SendUserEmailsJob.perform_now(peter.id, 'onboarding', true)
		  	expect(peter.invites.length).to eq(1)
			end
		end
	end

	describe 'user emails for offboarding' do
		let!(:immediate_user_email) {create(:user_email, user: peter, email_type: :nil, email_status: UserEmail::statuses[:incomplete], schedule_options: {send_email: 0})}
	  let!(:custome_date_user_email) {create(:user_email, user: peter, email_type: :offboarding, email_status: UserEmail::statuses[:incomplete], schedule_options: {date: Date.today, time: Time.now + 1.hour, send_email: 1})}
	  let!(:relative_start_date_user_email) {create(:user_email, user: peter, email_type: :nil, email_status: UserEmail::statuses[:incomplete], schedule_options: {duration: 30, send_email: 2, relative_key: "start date", duration_type: "days", due: "after"})}
	  let!(:relative_dob_user_email) {create(:user_email, user: peter, email_type: :offboarding, email_status: UserEmail::statuses[:incomplete], schedule_options: {duration: 60, send_email: 2, relative_key: "birthday", duration_type: "days", due: "after"})}

		context 'should send user emails for offboarding' do
			it 'delete selected emails and send remaining emails' do
				expect(peter.user_emails.length).to eq(4)
				peter.user_emails.try(:each) do |user_email|
				  user_email.invite_at = Inbox::SetInviteAt.new.set_invite_at(user_email)
				  user_email.save!
				end
		  	SendUserEmailsJob.perform_now(peter.id, 'offboarding', true, [custome_date_user_email.id, relative_dob_user_email.id])
			peter.user_emails.reload
			email_status = peter.user_emails.pluck(:email_status)
			completed = UserEmail::statuses[:completed]
		  	expect(peter.user_emails.length).to eq(2)
		  	expect(email_status.include?(completed)).to eq(true)
			end

			it 'should not create a invite for user' do
		  	SendUserEmailsJob.perform_now(peter.id, 'offboarding', true, [custome_date_user_email.id, relative_dob_user_email.id])
		  	expect(peter.invites.length).to eq(0)
			end
		end
	end
end
