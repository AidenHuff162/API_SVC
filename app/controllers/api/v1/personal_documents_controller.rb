module Api
  module V1
    class PersonalDocumentsController < BaseController
      include HistoryHandler
      
      before_action :authorize_user, except: [:destroy, :download_url]

      before_action only: [:index] do
        ::PermissionService.new.checkDocumentPlatformVisibility(current_user, params[:user_id] || current_user.id )
      end
      rescue_from CanCan::AccessDenied do |exception|
        render body: Sapling::Application::EMPTY_BODY, status: 204
      end

      load_and_authorize_resource only: [:destroy, :download_url, :show, :update]

      def index
        collection = PersonalDocumentsCollection.new(personal_document_params)
        respond_with collection.results, each_serializer: PersonalDocumentsSerializer::Basic
      end

      def show
        respond_with @personal_document, each_serializer: PersonalDocumentsSerializer::Basic
      end

      def create
      	save_respond_with_form
        create_document_history(current_company, current_user, personal_document_params[:title], 'complete')
      end

      def update
        save_respond_with_form
        create_document_history(current_company, current_user, @personal_document.title, 'update')
      end

      def download_url
        url = nil
        if @personal_document.attached_file
          filename = @personal_document.title + File.extname(@personal_document.attached_file.original_filename)
          url = params[:view_document].present? ? @personal_document.attached_file.file.url : @personal_document.attached_file.file.download_url(filename)
        end

        render json: {url: url, file_name: @personal_document.attached_file.original_filename}, status: 200
      end

      def destroy
        @personal_document.destroy!
        head 204
        create_document_history(current_company, current_user, @personal_document.title, 'delete')
      end

      private
        def save_respond_with_form
          form = PersonalDocumentForm.new(personal_document_params)
          form&.attached_file&.record&.skip_scanning = true
          form.save!
          respond_with form.record
        end

        def personal_document_params
          params.merge(created_by_id: current_user.id)
        end
    end
  end
end
