module Interactions
  module PaperTrail
    class RemoveOldVersion

      def perform
        ::PaperTrail::Version.where("created_at < ?", 1.year.ago).destroy_all
      end
    end
  end
end
