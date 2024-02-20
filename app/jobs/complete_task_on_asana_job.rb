class CompleteTaskOnAsanaJob
  include Sidekiq::Worker
  sidekiq_options :queue => :asana_integration, :retry => true, :backtrace => true

  def perform(tuc_id)
    tuc = TaskUserConnection.find_by(id: tuc_id)
    AsanaService::CompleteTask.new(tuc).perform if tuc
  end

end
