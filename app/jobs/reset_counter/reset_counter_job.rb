class ResetCounter::ResetCounterJob
  include Sidekiq::Worker
  sidekiq_options :queue => :fix_counter, :retry => false, :backtrace => true

    def perform
      Sapling::Application.load_tasks
      Rake::Task['fix_counters:all'].invoke
      Rake::Task.clear
    end
end
