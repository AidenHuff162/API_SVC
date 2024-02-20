class AlgoliaWorker < ApplicationJob

  def perform(id, record, remove)
    if remove
      index = Algolia::Index.new("User_#{ENV['ALGOLIA_INDEX_NAME']}")
      index.delete_object(id)
    else
      record.index!
    end
  end

end
