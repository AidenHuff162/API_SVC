require 'rails_helper'

RSpec.describe Inbox::TemporaryEmailTemplate do
  let(:company) {create(:company) }

 describe 'create_bulk_onboarding_templates' do
   before(:each) { @start_dates = [company.time.to_date, company.time.to_date-1.day] }

   it 'create bulk onboarding templates with default schedule options' do
      collection = InboxEmailTemplatesCollection.new({company_id: company.id})
      res = Inbox::TemporaryEmailTemplate.new(collection , @start_dates).call
      expect(res.count).to eq(collection.count)
    end

    it 'create bulk onboarding templates with relative key as anniversary' do
      email_template = company.email_templates.where.not(email_type: DEFAULT_NOTIFICATION_TEMPLATES).take
      email_template.schedule_options = {"due"=>nil, "date"=>nil, "time"=>nil, "duration"=>nil, "send_email"=>0, "relative_key"=>'anniversary', "duration_type"=>nil}
      email_template.save
      collection = InboxEmailTemplatesCollection.new({company_id: company.id })
      res = Inbox::TemporaryEmailTemplate.new(collection , [nil]).call
      expect(res[0].schedule_options['message']).to eq('Set a start date first for this new hire or change the scheduled date' )
    end

    it 'create bulk onboarding templates due 1 day before' do
      email_template = company.email_templates.where.not(email_type: DEFAULT_NOTIFICATION_TEMPLATES).take
      email_template.schedule_options = {"due"=>'before', "date"=>nil, "time"=>nil, "duration"=>1, "send_email"=>0, "relative_key"=>nil, "duration_type"=>'days'}
      email_template.save
      collection = InboxEmailTemplatesCollection.new({company_id: company.id })
      res = Inbox::TemporaryEmailTemplate.new(collection , @start_dates).call
      expect(res[0].schedule_options['due']).to eq("before")
      expect(res[0].schedule_options['duration']).to eq(1)
      expect(res[0].schedule_options['duration_type']).to eq("days")
    end

    it 'create bulk onboarding templates due 1 day after' do
      email_template = company.email_templates.where.not(email_type: DEFAULT_NOTIFICATION_TEMPLATES).take
      email_template.schedule_options = {"due"=>'after', "date"=>nil, "time"=>nil, "duration"=>1, "send_email"=>0, "relative_key"=>nil, "duration_type"=>'days'}
      email_template.save
      collection = InboxEmailTemplatesCollection.new({company_id: company.id })
      res = Inbox::TemporaryEmailTemplate.new(collection , @start_dates).call
      expect(res[0].schedule_options['due']).to eq("after")
      expect(res[0].schedule_options['duration']).to eq(1)
      expect(res[0].schedule_options['duration_type']).to eq("days")
    end

    it 'create bulk onboarding templates with relative key as start date' do
      email_template = company.email_templates.where.not(email_type: DEFAULT_NOTIFICATION_TEMPLATES).take
      email_template.schedule_options = {"due"=>nil, "date"=>nil, "time"=>nil, "duration"=>nil, "send_email"=>0, "relative_key"=>'start date', "duration_type"=>nil}
      email_template.save
      collection = InboxEmailTemplatesCollection.new({company_id: company.id })
      res = Inbox::TemporaryEmailTemplate.new(collection , @start_dates).call
      expect(res[0].schedule_options['message']).to eq('Selected date is in the past')
    end

    it 'create bulk onboarding templates with schedule option to as personal' do
      allow_any_instance_of(Company).to receive(:provisiong_account_exists?).and_return(true)
      email_template = company.email_templates.where.not(email_type: DEFAULT_NOTIFICATION_TEMPLATES).take
      collection = InboxEmailTemplatesCollection.new({company_id: company.id })
      res = Inbox::TemporaryEmailTemplate.new(collection , @start_dates).call
      expect(res[0].schedule_options['to']).to eq('personal')
    end

    it 'create bulk onboarding templates with schedule option to as personal' do
      email_template = company.email_templates.where.not(email_type: DEFAULT_NOTIFICATION_TEMPLATES).take
      collection = InboxEmailTemplatesCollection.new({company_id: company.id })
      res = Inbox::TemporaryEmailTemplate.new(collection , @start_dates).call
      expect(res[0].attachments.count).to eq(email_template.attachments.count)
    end
end
end
