module PaperTrail
  class RemoveOldVersionJob  < ApplicationJob

    def perform
      Interactions::PaperTrail::RemoveOldVersion.new.perform
    end
  end
end
