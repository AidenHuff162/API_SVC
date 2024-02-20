require 'rails_helper'

RSpec.describe EmailTemplate, type: :model do
  let(:user) { create(:user, super_user: true) }
  let(:company) { create(:company) }
  let(:email_template) { create(:email_template, meta:  { location_id: ['all'], team_id: ['all'], employee_type: ['all'], department_ids: ['all'] }) }
  let(:employee) {create(:nick, :manager_with_role, company:company)}
  let(:location) { create(:location) }
  let(:team) { create(:team) }

      
  describe 'Associations' do
    it { is_expected.to have_many(:attachments).class_name('UploadedFile::Attachment') }
    it { is_expected.to belong_to(:company) }
    it { is_expected.to belong_to(:editor).class_name('User') }
  end

  describe 'Database Validations' do
    it "is not valid without a subject" do
      et = EmailTemplate.new(subject: nil, description: '', email_type: 1)
      expect(et).to be_valid
      expect {et.save!}.to  raise_error(ActiveRecord::StatementInvalid)
    end

    it "is not valid without a description" do
      et = EmailTemplate.new(subject: '', description: nil, email_type: 1)
      expect(et).to be_valid
      expect {et.save!}.to  raise_error(ActiveRecord::StatementInvalid)
    end

    it "is not valid without an email type" do
      et = EmailTemplate.new(subject: '', description: '', email_type: nil)
      expect(et).to be_valid
      expect {et.save!}.to  raise_error(ActiveRecord::StatementInvalid)
    end

    it "checks if record is valid" do
      et = EmailTemplate.new(subject: '', description: '', email_type: 1)
      expect(et).to be_valid
      expect {et.save!}.not_to raise_error
    end
  end

  describe 'Model Callbacks' do
    it 'fixes line breaks on changing description' do
      expect(email_template).to receive(:fix_line_breaks)
      email_template.update(description: 'change')
    end
  end

  describe 'Business Logic' do
    it 'default selected option for department,location, status and permission group' do
      expect(email_template.department_ids).to match_array(['all'])
      expect(email_template.location_ids).to match_array(['all'])
      expect(email_template.status_ids).to match_array(['all'])
      expect(email_template.permission_group_ids).to match_array(['all'])
    end

    it 'selected option for department and location' do
      meta = email_template.meta
      meta['location_id'] = [location.id]
      meta['team_id'] = [team.id]
      email_template.update(meta: meta)
      # expect(email_template.meta['department_ids'][0].to_i).to be(team.id)
      expect(email_template.location_ids[0].to_i).to be(location.id)
      expect(email_template.department_ids[0].to_i).to be(team.id)
    end
  end

  describe 'order_by_priority' do
    let!(:email_template) { create(:email_template) }
    it 'order by priority' do
      res = EmailTemplate.all.order_by_priority
      expect(res).to eq(EmailTemplate.all.order(EmailTemplate.order_by_case))
    end
  end

end
