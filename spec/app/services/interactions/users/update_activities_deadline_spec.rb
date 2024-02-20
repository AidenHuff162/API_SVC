require 'rails_helper'

RSpec.describe Interactions::Users::UpdateActivitiesDeadline do
  let!(:user) {create(:user)}
  let!(:task) {create(:task, deadline_in: 5)}
  let!(:tuc) {create(:task_user_connection, is_custom_due_date: false, task: task, user: user)}
  
  describe 'Update activities deadline' do
    context 'update activities due date as per start date' do
      it "should update the date " do
        user.task_user_connections.take.update(before_due_date: user.start_date)
        Interactions::Users::UpdateActivitiesDeadline.new(user.id, Date.today + 2.days, true, false, user.start_date).perform
        expect(tuc.reload.due_date).to eq(Date.today + 7.days)
      end

      it "should not update the due date if task is completed " do
        tuc.complete!
        Interactions::Users::UpdateActivitiesDeadline.new(user.id, Date.today + 2.days, true, false, user.start_date).perform
        expect(tuc.reload.due_date).to_not eq(Date.today + 7.days)
      end

      it "should not update the due date if is_custom_due_date is true" do
        tuc.update_column(:is_custom_due_date, true)
        Interactions::Users::UpdateActivitiesDeadline.new(user.id, Date.today + 2.days, true, false, user.start_date).perform
        expect(tuc.reload.due_date).to_not eq(Date.today + 7.days)
      end

      it "should not update the due date if update_activties is false" do
        tuc.update_column(:is_custom_due_date, true)
        Interactions::Users::UpdateActivitiesDeadline.new(user.id, Date.today + 2.days, false, false, user.start_date).perform
        expect(tuc.reload.due_date).to_not eq(Date.today + 7.days)
      end
    end

    context 'update activities due date as per termination date' do
      before {user.update_column(:termination_date, Date.today + 2.days)}
      
      it "should update the date " do
        Interactions::Users::UpdateActivitiesDeadline.new(user.id, Date.today + 2.days, false, true, nil).perform
        expect(tuc.reload.due_date).to eq(Date.today + 7.days)
      end

      it "should not update the due date if task is completed " do
        tuc.complete!
        Interactions::Users::UpdateActivitiesDeadline.new(user.id, Date.today + 2.days, false, true, nil).perform
        expect(tuc.reload.due_date).to_not eq(Date.today + 7.days)
      end

      it "should not update the due date if is_custom_due_date is true" do
        tuc.update_column(:is_custom_due_date, true)
        Interactions::Users::UpdateActivitiesDeadline.new(user.id, Date.today + 2.days, false, true, nil).perform
        expect(tuc.reload.due_date).to_not eq(Date.today + 7.days)
      end

      it "should not update the due date if update_termination_activities is false" do
        tuc.update_column(:is_custom_due_date, true)
        Interactions::Users::UpdateActivitiesDeadline.new(user.id, Date.today + 2.days, false, false, nil).perform
        expect(tuc.reload.due_date).to_not eq(Date.today + 7.days)
      end
    end
    
  end
end
