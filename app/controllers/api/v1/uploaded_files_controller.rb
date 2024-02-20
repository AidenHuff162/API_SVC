module Api
  module V1
    class UploadedFilesController < ApiController
      FILE_TYPES = {
        'display_logo_image' => 'UploadedFile::DisplayLogoImage',
        'landing_page_image' => 'UploadedFile::LandingPageImage',
        'profile_image' => 'UploadedFile::ProfileImage',
        'gallery_image' => 'UploadedFile::GalleryImage',
        'milestone_image' => 'UploadedFile::MilestoneImage',
        'company_value_image' => 'UploadedFile::CompanyValueImage',
        'attachment' => 'UploadedFile::Attachment',
        'document' => 'UploadedFile::DocumentFile',
        'personal_document' => 'UploadedFile::PersonalDocumentFile',
        'document_upload_request' => 'UploadedFile::DocumentUploadRequestFile',
        'quill_attachment' => 'UploadedFile::QuillAttachment',
        'sftp_public_key' => 'UploadedFile::SftpPublicKey'
      }
      before_action :require_company!
      before_action :authenticate_user!
      before_action :verify_current_user_in_current_company!
      load_and_authorize_resource

      def create
        begin
          @uploaded_file.skip_scanning = true # if params['encrypted_key'].present? && ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base).decrypt_and_verify(params['encrypted_key'])
          @uploaded_file.save!
          if params[:is_task] == "true"
            respond_with @uploaded_file, serializer: AttachmentSerializer
          else
            respond_with @uploaded_file, serializer: AttachmentSerializer
          end
        rescue Exception => e
          if e.message == "Invalid Image Size"
            respond_with status: 'invalid_size'
          elsif e.message == "Invalid File Type"
            respond_with status: 'invalid_file_type'
          elsif e.message == "Invalid File Size"
            respond_with status: 'invalid_file_size'
          elsif e.message == "Malicious File"
            respond_with status: 'malicious_file'
          else
            respond_with status: 'invalid_file'
          end
        end
      end

      def update
        @uploaded_file.update(uploaded_file_params)
        respond_with @uploaded_file
      end

      def destroy
        if @uploaded_file.destroy
          respond_with status: 202
        else
          render json: {errors: [{messages: @uploaded_file.errors.full_messages, status: "422"}]}, status: 422
        end
      end

      def destroy_all_unused
        files_to_remove = UploadedFile.where(id: params[:ids])
        if files_to_remove.destroy_all
          respond_with status: 202
        else
          render json: {errors: [{messages: files_to_remove.errors.full_messages, status: "422"}]}, status: 422
        end
      end

      def scan_file
        @uploaded_file = UploadedFile.new(uploaded_file_params)
        key = nil
        begin
          key = Clamby.safe?(@uploaded_file.file.path)
          File.delete(@uploaded_file.file.path)
        rescue Exception => e
          File.delete(@uploaded_file.file.path)
        end
        if key
          crypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base)
          respond_with json: {encrypted_key: crypt.encrypt_and_sign(key)}, status: 200
        else
          render json: {errors: [{messages: ['Malicious File'], status: "422"}]}, status: 422
        end
      end

      private

      def uploaded_file_params
        type = FILE_TYPES[params[:type]]
        raise ActiveRecord::RecordNotFound if type.nil?

        params.permit(
          :file, :entity_id, :entity_type, :remove_file
        ).merge(company_id: current_company.id).merge(type: type)
      end
    end
  end
end
