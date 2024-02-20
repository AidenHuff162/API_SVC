module PaperworkTemplateSerializer
  class Full < ActiveModel::Serializer
    attributes :id, :hellosign_template_id, :hellosign_template_edit_url, :company_id, :document_url,
               :created_at, :position, :representative_id, :representative_pict, :is_manager_representative, :document_size, :new_template_id
    has_one :document, serializer: DocumentSerializer::Full
    has_one :representative, serializer: UserSerializer::People
    belongs_to :user, serializer: UserSerializer::Basic

    def document_url
      filename = "#{object.document.title}.pdf"
      object.document&.attached_file&.file&.download_url(filename)
    end

    def document_size
      object.document&.attached_file&.file&.size
    end

    def representative_pict
      object['representative_id'].present? ? User.find_by(id: object['representative_id']).picture : nil
    end

  end
end
