require 'rails_helper'
RSpec.describe PeriodicJobs::Integrations::Asana::SyncTasksFromAsana, type: :job do
  it 'should enque SyncTasksFromAsana job in sidekiq' do
  	tasks_from_asana_job_size = Sidekiq::Queues["asana_integration"].size
  	PeriodicJobs::Integrations::Asana::SyncTasksFromAsana.new.perform
    expect(Sidekiq::Queues["asana_integration"].size).to eq(tasks_from_asana_job_size + 1)
  end
end