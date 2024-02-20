require 'rails_helper'

RSpec.describe Interactions::Users::NotifyCommentTaskOwnerEmail do

  before do
    stub_request(:post, "https://api.sendgrid.com/v3/mail/send").to_return(status: 200, body: "", headers: {})
  end
  describe 'comment task owner' do
    context 'no user mentioned comment' do
      let!(:company) {create(:company_with_user, new_pending_hire_emails: true)}
      let!(:user) {create(:peter, company: company)}
      let!(:task) {create(:task)}    
      let!(:task_user_connection) {create(:task_user_connection, task: task, user: user, agent_id: user.id)}
      let!(:comment) {create(:comment, commenter: user, commentable: task_user_connection , commentable_type: 'TaskUserConnection', mentioned_users: [], company: company)}
      
      it 'should notify task owner' do        
        expect{Interactions::Users::NotifyCommentTaskOwnerEmail.new(comment).perform}.to change{CompanyEmail.all.count}.by(1)
      end
    end
  end
end
