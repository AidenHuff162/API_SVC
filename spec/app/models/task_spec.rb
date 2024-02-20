require 'rails_helper'

RSpec.describe Task, type: :model do
  let(:company) { FactoryGirl.create(:company)}
  let(:user) {FactoryGirl.create(:user, company: company)}
  let(:workstream) {FactoryGirl.create(:workstream, company_id: company.id)}
  let(:task) {FactoryGirl.create(:task, workstream_id: workstream.id, owner_id: user.id)}
  let(:task2) {FactoryGirl.create(:task, workstream_id: workstream.id, owner_id: user.id)}

  describe 'Associations' do
    it { is_expected.to belong_to(:owner).class_name('User') }
    it { is_expected.to belong_to(:workstream).counter_cache }
    it { is_expected.to belong_to(:workspace) }
    it { is_expected.to belong_to(:custom_field) }
    it { is_expected.to have_many(:task_user_connections) }
    it { is_expected.to have_many(:sub_tasks).dependent(:destroy) }
    it { is_expected.to have_many(:attachments).class_name('UploadedFile::Attachment').dependent(:destroy) }
  end

  describe 'Nested attributes' do
    it { should accept_nested_attributes_for(:sub_tasks).allow_destroy(true)}
    it { should accept_nested_attributes_for(:task_user_connections)}
  end

  describe 'Validation' do
    context 'name' do
      it { is_expected.to validate_presence_of(:name) }
    end

    context 'workstream' do
      it { is_expected.to validate_presence_of(:workstream) }
    end

    context 'deadline_in' do
      it { is_expected.to validate_presence_of(:deadline_in) }
    end

    context 'owner id' do
      before { allow_any_instance_of(Task).to receive(:task_type_owner?).and_return(true)}
      it { is_expected.to validate_presence_of(:owner_id)}
    end

    context 'task name uniqueness' do
      it 'should check for name uniqueness' do
        task2.name = task.name
        expect { task2.save! }.to raise_error(ActiveRecord::RecordInvalid , /Another task with same name exists./)
      end
    end
  end

  describe 'Attribute accessor' do
    it { should respond_to :updated_from_admin_tasks}
    it { should respond_to :is_retroactive}
    it { should respond_to :agent_id}
  end

  describe 'Callbacks' do
    context 'should run before and after create callbacks' do
      it "should set owner id to nil" do
        task1 = create(:task, task_type: 'hire')
        expect(task1.owner_id).to eq(nil)
      end

      it 'should not update task user connection for existing streams if user is not onboarded' do
        user2 = create(:user, current_stage: 1, company_id: company.id)
        task3 = create(:task, workstream_id: workstream.id, owner_id: user2.id)
        # task_user_connection = create(:task_user_connection, task_id: task3.id, user_id: user2.id)
        task1 = create(:task, updated_from_admin_tasks: "true", is_retroactive: "true", workstream_id: workstream.id, owner_id: user.id)
        expect(task1.task_user_connections.count).to eq(0)
      end

      it 'should update task user connection for existing streams if user is inivited and task type is hire' do
        user2 = create(:user, current_stage: 0, company_id: company.id)
        task3 = create(:task, task_type: 'hire', workstream_id: workstream.id)
        task_user_connection = create(:task_user_connection, task_id: task3.id, user_id: user2.id)
        task1 = create(:task, task_type: 'hire', updated_from_admin_tasks: "true", is_retroactive: "true", workstream_id: workstream.id)
        expect(task1.task_user_connections.count).to be > 0
      end

      it 'should update task user connection for existing streams if user is departed and task type is manager' do
        user2 = create(:user, current_stage: 6, company_id: company.id, manager_id: user.id)
        task3 = create(:task, workstream_id: workstream.id, owner_id: user2.id)
        task_user_connection = create(:task_user_connection, task_id: task3.id, user_id: user2.id)
        task1 = create(:task, task_type: 'manager', updated_from_admin_tasks: "true", is_retroactive: "true", workstream_id: workstream.id)
        expect(task1.task_user_connections.count).to be > 0
      end

      it 'should update task user connection for existing streams if user is departed and task type is buddy' do
        user2 = create(:user, current_stage: 6, company_id: company.id, buddy_id: user.id)
        task3 = create(:task, workstream_id: workstream.id, owner_id: user2.id)
        task_user_connection = create(:task_user_connection, task_id: task3.id, user_id: user2.id)
        task1 = create(:task, task_type: 'buddy', updated_from_admin_tasks: "true", is_retroactive: "true", workstream_id: workstream.id)
        expect(task1.task_user_connections.count).to be > 0
      end

      it 'should update task user connection for existing streams if task type is workspace' do
        workspace = create(:workspace)
        task_user_connection = create(:task_user_connection, task_id: task2.id, user_id: user.id)
        task1 = create(:task, task_type: 'workspace', updated_from_admin_tasks: "true", is_retroactive: "true", workstream_id: workstream.id, workspace_id: workspace.id)
        expect(task1.task_user_connections.count).to be > 0
      end

      it 'should update task user connection for existing streams if task type owner' do
        task_user_connection = create(:task_user_connection, task_id: task2.id, user_id: user.id)
        task1 = create(:task, updated_from_admin_tasks: "true", is_retroactive: "true", workstream_id: workstream.id, owner_id: user.id)
        expect(task1.task_user_connections.count).to be > 0
      end
    end
    context 'should run before and after update callbacks' do
      it "should set owner id to nil" do
        task.update!(task_type: 'hire')
        expect(task.owner_id).to eq(nil)
      end

      it 'should update task connection with user2 if task deadline changed' do
        user2 = create(:user, company_id: company.id)
        deadline_in_temp = task2.deadline_in
        task_user_connection = create(:task_user_connection, task_id: task2.id, user_id: user.id)
        task2.update!(updated_from_admin_tasks: "true", is_retroactive: "true", deadline_in: 3, owner_id: user2.id)
        expect(task2.deadline_in).not_to eq(deadline_in_temp)
      end

      it 'should update task connection with user3 if task deadline changes' do
        user3 = create(:user, company_id: company.id)
        deadline_in_temp = task2.deadline_in
        task_user_connection = create(:task_user_connection, task_id: task2.id, user_id: user.id)
        task2.update!(updated_from_admin_tasks: "true", is_retroactive: "true", deadline_in: 5, owner_id: user3.id)
        expect(task2.deadline_in).not_to eq(deadline_in_temp)
      end

      it 'should update task connection with users if task deadline changed and is user last day' do
        user2 = create(:user, company_id: company.id, last_day_worked: Date.today)
        deadline_in_temp = task2.deadline_in
        task_user_connection = create(:task_user_connection, task_id: task2.id, user_id: user2.id)
        task2.update!(updated_from_admin_tasks: "true", is_retroactive: "true", deadline_in: 3, owner_id: user2.id)
        expect(task2.deadline_in).not_to eq(deadline_in_temp)
      end

      it 'should update task connection with users if task deadline changed and is user second last day' do
        user3 = create(:user, company_id: company.id, last_day_worked: Date.today - 1.days)
        deadline_in_temp = task2.deadline_in
        task_user_connection = create(:task_user_connection, task_id: task2.id, user_id: user3.id)
        task2.update!(updated_from_admin_tasks: "true", is_retroactive: "true", deadline_in: 3, owner_id: user3.id)
        expect(task2.deadline_in).not_to eq(deadline_in_temp)
      end

      it 'should update task connection with users if task owner is changed by user 2' do
        user2 = create(:user, company_id: company.id)
        task_user_connection = create(:task_user_connection, task_id: task2.id, user_id: user.id)
        task2.update!(updated_from_admin_tasks: "true", is_retroactive: "true", task_type: 'owner', owner_id: user2.id)
        expect(task2.task_user_connections.first.owner_id).to eq(user2.id)
      end

      it 'should update task connection with users if task owner is changed by user 3' do
        user3 = create(:user, company_id: company.id)
        task_user_connection = create(:task_user_connection, task_id: task2.id, user_id: user.id)
        task2.update!(updated_from_admin_tasks: "true", is_retroactive: "true", task_type: 'owner', owner_id: user3.id)
        expect(task2.task_user_connections.first.owner_id).to eq(user3.id)
      end

      it 'should update task connection with users if task type is changed to manager for user 2' do
        user2 = create(:user, company_id: company.id, manager_id: user.id)
        task_user_connection = create(:task_user_connection, task_id: task2.id, user_id: user2.id)
        task2.update!(updated_from_admin_tasks: "true", is_retroactive: "true", task_type: 'manager', owner_id: user2.id)
        expect(task2.task_user_connections.first.owner_id).to eq(user.id)
      end

      it 'should update task connection with users if task type is changed to manager for user 3' do
        user3 = create(:user, company_id: company.id, manager_id: user.id)
        task_user_connection = create(:task_user_connection, task_id: task2.id, user_id: user3.id)
        task2.update!(updated_from_admin_tasks: "true", is_retroactive: "true", task_type: 'manager', owner_id: user3.id)
        expect(task2.task_user_connections.first.owner_id).to eq(user.id)
      end

      it 'should update task connection with users if task type is changed to buddy for user 2' do
        user2 = create(:user, company_id: company.id, buddy_id: user.id)
        task_user_connection = create(:task_user_connection, task_id: task2.id, user_id: user2.id)
        task2.update!(updated_from_admin_tasks: "true", is_retroactive: "true", task_type: 'buddy', owner_id: user2.id)
        expect(task2.task_user_connections.first.owner_id).to eq(user.id)
      end

      it 'should update task connection with users if task type is changed to buddy for user 3' do
        user3 = create(:user, company_id: company.id, buddy_id: user.id)
        task_user_connection = create(:task_user_connection, task_id: task2.id, user_id: user3.id)
        task2.update!(updated_from_admin_tasks: "true", is_retroactive: "true", task_type: 'buddy', owner_id: user3.id)
        expect(task2.task_user_connections.first.owner_id).to eq(user.id)
      end

      it 'should update task connection with users if task type is changed to hire for user 2' do
        user2 = create(:user, company_id: company.id)
        task_user_connection = create(:task_user_connection, task_id: task2.id, user_id: user2.id)
        task2.update!(updated_from_admin_tasks: "true", is_retroactive: "true", task_type: 'hire', owner_id: user2.id)
        expect(task2.task_user_connections.first.owner_id).to eq(user2.id)
      end

      it 'should update task connection with users if task type is changed to hire for user 3' do
        user3 = create(:user, company_id: company.id)
        task_user_connection = create(:task_user_connection, task_id: task2.id, user_id: user3.id)
        task2.update!(updated_from_admin_tasks: "true", is_retroactive: "true", task_type: 'hire', owner_id: user3.id)
        expect(task2.task_user_connections.first.owner_id).to eq(user3.id)
      end

      it "should set before deadline to nil" do
        task2.update!(time_line: 'later')
        task2.update!(time_line: 'immediately')
        expect(task2.before_deadline_in).to eq(0)
      end

      it "should set before deadline to later" do
        task2.update!(time_line: 'immediately')
        task2.update!(time_line: 'later')
        expect(task2.before_deadline_in).to eq(0)
      end
    end

    context 'should run before and after save callbacks' do
      it "should sanitize" do
        task2.update!(name: '<p>random</p>')
        expect(task2.sanitized_name).to eq(Nokogiri::HTML(task2.name).text)
      end
    end

    context 'should run before and after destroy callbacks for task 3' do
      it "should repositions tasks" do
        task1 = create(:task, workstream_id: workstream.id)
        task3 = create(:task, workstream_id: workstream.id)
        temp = task1.position
        task1.destroy!
        task3 = task3.workstream.tasks.find_by(id: task3.id)
        expect(task3.position).to eq(temp)
      end
    end

    context 'should run before and after destroy callbacks for task 2' do
      it "should repositions tasks" do
        task1 = create(:task, workstream_id: workstream.id)
        task2 = create(:task, workstream_id: workstream.id)
        temp = task1.position
        task1.destroy!
        task2 = task2.workstream.tasks.find_by(id: task2.id)
        expect(task2.position).to eq(temp)
      end
    end
  end

  describe 'is_task_due_immediately?' do
    it 'should check is task due immediately' do
      res = task.is_task_due_immediately?
      expect(res).to eq(false)
    end
  end
end
