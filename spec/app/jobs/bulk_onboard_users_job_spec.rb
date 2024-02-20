require 'rails_helper'

RSpec.describe BulkOnboardUsersJob, type: :job do

  let!(:company) { create(:company) }
  let!(:user) { create(:user, company: company) }
  let(:pending_hire) { create(:pending_hire, company: company) }

  it 'should create user' do
    params = JSON.parse({'pending_hires': [pending_hire.attributes.merge({'email': Faker::Internet.email, 'start_date': Date.today.to_s})], 
      'custom_sections': [], 'custom_tables': [], 'tasks': [], 'template_ids': [], 'workstream_count': 0, 'pt_dur': []}.to_json)
    expect{BulkOnboardUsersJob.new.perform(params, company.id, user.id)}.to change{company.users.count}.by(1)
  end

  it 'should not create user' do
    params = JSON.parse({'pending_hires': [pending_hire.attributes.merge({'email': Faker::Internet.email, 'start_date': Date.today.to_s, 'user_id': user.id})], 
      'custom_sections': [], 'custom_tables': [], 'tasks': [], 'template_ids': [], 'workstream_count': 0, 'pt_dur': []}.to_json)
    expect{BulkOnboardUsersJob.new.perform(params, company.id, user.id)}.to change{company.users.count}.by(0)
  end
end