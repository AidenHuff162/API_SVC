require 'rails_helper'

RSpec.describe DestroyTaskJob, type: :job do

  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  it "should delete task user connections when a task is destroyed" do
    workstream = create(:workstream, company: company)
    task = create(:task, workstream: workstream)
    task_user_connection = create(:task_user_connection, user: user, task: task)

    expect(user.task_user_connections[0].task_id).to eq(task.id)
    expect(user.task_user_connections.length).to eq(1)

    DestroyTaskJob.perform_now(task.id)

    user.task_user_connections.reload()
    expect(user.task_user_connections.with_deleted.count).to eq(1)
  end

end
