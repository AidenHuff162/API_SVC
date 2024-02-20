require 'rails_helper'

RSpec.describe ReassignManagerActivitiesService do
  describe 'assign user activities to new manager' do  
    before {User.current = user}
    let!(:company) { create(:company) }
    let!(:manager) { create(:user, company: company, role: User.roles[:employee])}
    let!(:new_manager) { create(:user, company: company, role: User.roles[:employee])}
    let!(:user) { create(:user_with_manager_and_policy, state: :active, current_stage: :registered, company: company, manager: manager) }
    let!(:pto_request){ create(:pto_request, pto_policy: user.pto_policies.first, user: user,
      partial_day_included: false,  user: user, begin_date: user.start_date + 2.days,
      end_date: user.start_date + 2.days, status: 0) }
    let!(:doc) { create(:document, company: company) }
    let!(:paperwork_request) { create(:paperwork_request, :request_skips_validate, document: doc, user: user, co_signer_id: manager.id, co_signer_type: PaperworkRequest.co_signer_types[:manager], state: "signed") }
    let!(:paperwork_template) { create(:paperwork_template, :template_skips_validate, document: doc, user: user, is_manager_representative: true, company: company) }
    let!(:task){ create(:task, task_type: Task.task_types[:manager])}
    let!(:task_user_connection){ create(:task_user_connection, task: task, user: user, state: 'in_progress', owner_id: manager.id)}
  
    context 'update repsentative of paperwork template if previous manager is present' do
      it 'should update co_signer_id of paperwork_template' do
        user.update!(manager_id: new_manager.id)
        ReassignManagerActivitiesService.new(company, user.id, manager.id).perform
        paperwork_request.reload
        expect(paperwork_request.co_signer_id).to eq(new_manager.id)
      end

      it 'should not update co_signer_id of paperwork_template if previous manager id is not present' do
        user.update!(manager_id: new_manager.id)
        ReassignManagerActivitiesService.new(company, user.id, nil).perform
        paperwork_request.reload
        expect(paperwork_request.co_signer_id).to eq(manager.id)
      end
    end
    
    context 'pending pto requests email to manager' do
      it 'should send email to mananger for pending pto request' do
        expect{ReassignManagerActivitiesService.new(company, user.id, nil).perform}.to change{CompanyEmail.all.count}.by(1)
      end
    end
    
    context 'assign user tasks to new manager' do
      it 'should assign user tasks to new manager' do
        user.update!(manager_id: new_manager.id)
        ReassignManagerActivitiesService.new(company, user.id, manager.id).perform
        task_user_connection.reload
        expect(task_user_connection.owner_id).to eq(new_manager.id)
      end
    end
  end
end
