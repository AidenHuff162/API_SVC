require 'rails_helper'

RSpec.describe Comment, type: :model do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:workstream) { create(:workstream, company: company ) }
  let(:task) { create(:task, workstream: workstream) }
  let(:task_user_connection) { create(:task_user_connection, task: task, user: user, agent_id: user.id) }

  describe 'validation and email callback for TUC' do
    context 'validation of description' do
      it 'should not have html injected' do
        comment = Comment.new(description: "<a>hello!</a> click me", commentable_id: task_user_connection.id, commentable_type: 'TaskUserConnection', commenter: user)
        expect(comment.invalid?).to eq(true)
      end

      it 'should be valid without html injected' do
        comment = Comment.new(description: "hello!", commentable_id: task_user_connection.id, commentable_type: 'TaskUserConnection', commenter: user)
        expect(comment.invalid?).to eq(false)
      end
    end
  end

  describe '#associations' do
    it { should belong_to(:company) }
    it { should belong_to(:commenter) }
    it { should belong_to(:commentable) }
  end

  describe '#before_save' do
    let(:nick) { create(:user_with_manager_and_policy, company: company, start_date: Date.today - 1.year) }
    before { User.current = nick}
    let(:pto_request) { create(:pto_request_skip_send_email_callback, user: nick, pto_policy: nick.pto_policies.first, partial_day_included: false, status: 0, begin_date: company.time.to_date, end_date: ( company.time.to_date + 2.days), balance_hours: 24) }
    let!(:comment) {create(:comment, description: "hello! click me", commentable: pto_request, commenter: user)}

    context 'company_assignment' do
      it 'should set company id for comment' do
        expect(comment.company_id).to_not eq(nil)
      end
    end
    context 'with attr_accesors set to true' do
      before do
      	comment.check_for_mail = true
      end
      it 'should create activity if attr_accesor are set to true' do
        comment.create_activity = true
        comment.save
        expect(user.activities.size).to eq(1)
      end
      it 'should dispatch an email to the manager' do
        expect{ create(:comment, check_for_mail: true, description: "hello! click me", commentable: pto_request, commenter: user)}.to change(CompanyEmail, :count).by(1)
      end
    end
    context 'with mentioned users' do
    	let(:user1){ create(:user, company: company) }
    	let(:user2){ create(:user, company: company) }

    	before do
    		@comment = build(:comment, description: "hey, how are you", commentable_id: task_user_connection.id, commentable_type: 'TaskUserConnection', commenter: user, company: user.company)
    		@comment.mentioned_users << user1.id.to_s
    		@comment.mentioned_users << user2.id.to_s
    	end
    	it 'should dispatch an email to the mentioned users' do
    		expect{@comment.save}.to change(CompanyEmail, :count).by_at_least(2)
    	end
    end
  end
end
