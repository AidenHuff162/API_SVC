require 'rails_helper'

RSpec.describe WebhookEventServices::ParamsBuilderService do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:pending_hire) { create(:pending_hire, company: company) }
  let(:webhook) { create(:webhook,  company: company) }
  let(:current_user) { create(:user)}
  let(:key_date_change_webhook) { create(:webhook, configurable: { date_types: ['start_date'] },  company: company) }
  let(:profile_change_webhook) { create(:webhook, configurable: { fields: ['first_name'] },  company: company) }

  describe '#build_request_params' do
    it 'should return pending hire params with valid keys if pending_hire is present' do
      params = ::WebhookEventServices::ParamsBuilderService.new.build_request_params(company, {type: 'new_pending_hire', action: 'create', pending_hire_id: pending_hire.id}.with_indifferent_access, webhook)

      expect(params[:webhook_event][:pending_hire].keys).to eq ([:action, :source, :personalEmail, :firstName, :preferredName, :lastName, :startDate, :jobTitle, :department, :location, :status, :employmentStatus, :pendingHireId])
      expect(params[:webhook_event].keys).to eq ([:customer, :pending_hire])

    end

    it 'should return pending hire params with valid keys if pending_hire is not present' do
      params = ::WebhookEventServices::ParamsBuilderService.new.build_request_params(company, {type: 'new_pending_hire', action: 'create', pending_hire_id: nil}.with_indifferent_access, webhook)

      expect(params[:webhook_event][:pending_hire].keys).to eq ([:action, :source])
      expect(params[:webhook_event].keys).to eq ([:customer, :pending_hire])
    end

    it 'should return stage_completed params with valid keys' do
      params = ::WebhookEventServices::ParamsBuilderService.new.build_request_params(company, {type: 'stage_completed', action: 'create', triggered_for: user.id, stage: :preboarding}.with_indifferent_access, webhook)
      
      expect(params[:webhook_event][:user].keys).to eq ([:email, :personalEmail, :firstName, :preferredName, :lastName, :startDate, :jobTitle, :department, :location, :status, :employmentStatus, :userId, :StageCompleted])
      expect(params[:webhook_event].keys).to eq ([:customer, :user])
    end

    it 'should return stage_started params with valid keys' do
      params = ::WebhookEventServices::ParamsBuilderService.new.build_request_params(company, {type: 'stage_started', action: 'create', triggered_for: user.id, stage: :preboarding}.with_indifferent_access, webhook)
      
      expect(params[:webhook_event][:user].keys).to eq ([:email, :personalEmail, :firstName, :preferredName, :lastName, :startDate, :jobTitle, :department, :location, :status, :employmentStatus, :userId, :StageStarted])
      expect(params[:webhook_event].keys).to eq ([:customer, :user])
    end

    it 'should return key_date_reached params with valid keys' do
      params = ::WebhookEventServices::ParamsBuilderService.new.build_request_params(company, {type: 'key_date_reached', action: 'create', triggered_for: user.id, date_types: ['start_date']}.with_indifferent_access, key_date_change_webhook)
      
      expect(params[:webhook_event][:user].keys).to eq ([:email, :personalEmail, :firstName, :preferredName, :lastName, :startDate, :jobTitle, :department, :location, :status, :employmentStatus, :userId, :keydatesReached])
      expect(params[:webhook_event].keys).to eq ([:customer, :user])
    end

    it 'should return profile_changed params with valid keys' do
      params = ::WebhookEventServices::ParamsBuilderService.new.build_request_params(company, {type: 'profile_changed', action: 'create', triggered_for: user.id, values_changed: [field_id: 'first_name', values: 2.days.ago]}.with_indifferent_access, profile_change_webhook)
      
      expect(params[:webhook_event][:user].keys).to eq ([:email, :personalEmail, :userId, :fields_changed])
      expect(params[:webhook_event].keys).to eq ([:customer, :user])
    end

    it 'should return onboarding_params' do
      params = ::WebhookEventServices::ParamsBuilderService.new.build_request_params(company, {type: 'onboarding', stage: 'started', triggered_for: user.id, triggered_by: current_user.id , user_id: user.id, user: user}.with_indifferent_access, webhook)
      expect(params[:webhook_event][:eventActivity].keys).to eq ([:activityState, :activityInitiatedByGuid])
      expect(params[:webhook_event].keys).to eq ([:customer ,:eventType, :eventTime,:eventActivity ,:email , :personalEmail, :firstName, :preferredName, :lastName, :userGuid, :userId, :status, :current_stage, :startDate, :accountProvision])
      expect(params[:webhook_event][:accountProvision].keys).to eq ([:accountProvider, :accountProvisionRequest, :accountProviderSchedule, :accountProvisionTime])
      expect(params[:webhook_event][:customer].keys).to eq ([:domain, :companyID])   
    end

    it 'should return onboarding_params' do
      params = ::WebhookEventServices::ParamsBuilderService.new.build_request_params(company, {type: 'onboarding', stage: 'completed', triggered_for: user.id, triggered_by: current_user.id , user_id: user.id, user: user}.with_indifferent_access, webhook)
      expect(params[:webhook_event][:eventActivity].keys).to eq ([:activityState, :activityInitiatedByGuid])
      expect(params[:webhook_event].keys).to eq ([:customer ,:eventType, :eventTime,:eventActivity ,:email , :personalEmail, :firstName, :preferredName, :lastName, :userGuid, :userId, :status, :current_stage, :startDate, :accountProvision])
      expect(params[:webhook_event][:accountProvision].keys).to eq ([:accountProvider, :accountProvisionRequest, :accountProviderSchedule, :accountProvisionTime])
      expect(params[:webhook_event][:customer].keys).to eq ([:domain, :companyID])   
    end

    it 'should return onboarding_params' do
      params = ::WebhookEventServices::ParamsBuilderService.new.build_request_params(company, {type: 'onboarding', stage: 'cancelled', triggered_for: user.id, triggered_by: current_user.id , user_id: user.id, user: user}.with_indifferent_access, webhook)
      expect(params[:webhook_event][:eventActivity].keys).to eq ([:activityState, :activityInitiatedByGuid])
      expect(params[:webhook_event].keys).to eq ([:customer ,:eventType, :eventTime,:eventActivity ,:email , :personalEmail, :firstName, :preferredName, :lastName, :userGuid, :userId, :status, :current_stage, :startDate, :accountProvision])
      expect(params[:webhook_event][:accountProvision].keys).to eq ([:accountProvider, :accountProvisionRequest, :accountProviderSchedule, :accountProvisionTime])
      expect(params[:webhook_event][:customer].keys).to eq ([:domain, :companyID])   
    end

    it 'should return offboarding_params' do
      params = ::WebhookEventServices::ParamsBuilderService.new.build_request_params(company, {type: 'offboarding', stage: 'started', triggered_for: user.id, triggered_by: current_user.id , user_id: user.id, user: user}.with_indifferent_access, webhook)
      expect(params[:webhook_event][:eventActivity].keys).to eq ([:activityState, :activityInitiatedByGuid])
      expect(params[:webhook_event].keys).to eq ([:customer ,:eventType, :eventTime,:eventActivity ,:email , :personalEmail, :firstName, :preferredName, :lastName, :userGuid, :userId, :status, :current_stage, :terminationDate, :lastDayWorked, :terminationType, :eligibleForRehire, :accessCutOff])
      expect(params[:webhook_event][:accessCutOff].keys).to eq ([:accessCutOffSchedule, :accessCutOffTime])
      expect(params[:webhook_event][:customer].keys).to eq ([:domain, :companyID])   
    end

    it 'should return offboarding_params' do
      params = ::WebhookEventServices::ParamsBuilderService.new.build_request_params(company, {type: 'offboarding', stage: 'completed', triggered_for: user.id, triggered_by: current_user.id , user_id: user.id, user: user}.with_indifferent_access, webhook)
      expect(params[:webhook_event][:eventActivity].keys).to eq ([:activityState, :activityInitiatedByGuid])
      expect(params[:webhook_event].keys).to eq ([:customer ,:eventType, :eventTime,:eventActivity ,:email , :personalEmail, :firstName, :preferredName, :lastName, :userGuid, :userId, :status, :current_stage, :terminationDate, :lastDayWorked, :terminationType, :eligibleForRehire, :accessCutOff])
      expect(params[:webhook_event][:accessCutOff].keys).to eq ([:accessCutOffSchedule, :accessCutOffTime])
      expect(params[:webhook_event][:customer].keys).to eq ([:domain, :companyID])   
    end
    it 'should return offboarding_params' do
      params = ::WebhookEventServices::ParamsBuilderService.new.build_request_params(company, {type: 'offboarding', stage: 'cancelled', triggered_for: user.id, triggered_by: current_user.id , user_id: user.id, user: user}.with_indifferent_access, webhook)
      expect(params[:webhook_event][:eventActivity].keys).to eq ([:activityState, :activityInitiatedByGuid])
      expect(params[:webhook_event].keys).to eq ([:customer ,:eventType, :eventTime,:eventActivity ,:email , :personalEmail, :firstName, :preferredName, :lastName, :userGuid, :userId, :status, :current_stage, :terminationDate, :lastDayWorked, :terminationType, :eligibleForRehire, :accessCutOff])
      expect(params[:webhook_event][:accessCutOff].keys).to eq ([:accessCutOffSchedule, :accessCutOffTime])
      expect(params[:webhook_event][:customer].keys).to eq ([:domain, :companyID])   
    end
  end
end 
