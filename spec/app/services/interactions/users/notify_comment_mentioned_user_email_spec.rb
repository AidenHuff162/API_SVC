require 'rails_helper'

RSpec.describe Interactions::Users::NotifyCommentMentionedUserEmail do

  before do
    stub_request(:post, "https://api.sendgrid.com/v3/mail/send").to_return(status: 200, body: "", headers: {})
  end
  describe 'comment mentions' do
    let!(:company) {create(:company, new_pending_hire_emails: true)}
    let!(:user) {create(:user, company: company)}
    let!(:nick) {create(:user_with_manager_and_policy, company: company)}
    let!(:peter) {create(:peter, company: company)}
    let!(:task) {create(:task)}
    let!(:task_user_connection) {create(:task_user_connection, task: task, user: user, agent_id: user.id)}

      context 'one user mentioned' do
        let!(:comment) {create(:comment, commenter: user, commentable_id: task_user_connection.id , commentable_type: 'TaskUserConnection', mentioned_users: [nick.id], company: company)}
        it 'should notify one user' do
          expect{Interactions::Users::NotifyCommentMentionedUserEmail.new(comment).perform}.to change{CompanyEmail.all.count}.by(1)
        end

        it 'should notify nick' do
          Interactions::Users::NotifyCommentMentionedUserEmail.new(comment).perform
          expect(CompanyEmail.last.to[0]).to eq(nick.personal_email)
        end
      end

      context 'two user mentioned' do
        let!(:comment) {create(:comment, commenter: user, commentable_id: task_user_connection.id , commentable_type: 'TaskUserConnection', mentioned_users: [nick.id, peter.id], company: company)}
        it 'should notify all users' do
          expect{Interactions::Users::NotifyCommentMentionedUserEmail.new(comment).perform}.to change{CompanyEmail.all.count}.by(2)
        end

        it 'should notify nick and peter' do
          Interactions::Users::NotifyCommentMentionedUserEmail.new(comment).perform
          expect([nick.personal_email, peter.personal_email].include?(CompanyEmail.last.to[0])).to eq(true)
          expect([nick.personal_email, peter.personal_email].include?(CompanyEmail.last(2).first.to[0])).to eq(true)
        end
      end

      context 'no user mentioned' do
        let!(:comment) {create(:comment, commenter: user, commentable_id: task_user_connection.id , commentable_type: 'TaskUserConnection', mentioned_users: [], company: company)}
        it 'should not notify any user' do
          expect{Interactions::Users::NotifyCommentMentionedUserEmail.new(comment).perform}.to change{CompanyEmail.all.count}.by(0)
        end
      end


    end


end
