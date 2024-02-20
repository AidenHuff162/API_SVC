module Api
  module V1
    class WorkspaceImagesController < ApiController
      before_action :authenticate_user!

      def index
        respond_with WorkspaceImage.all, each_serializer: WorkspaceImageSerializer
      end
    end
  end
end
