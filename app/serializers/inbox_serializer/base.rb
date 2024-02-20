module InboxSerializer
  class Base < ActiveModel::Serializer
    attributes :id, :subject, :email_to, :cc, :bcc, :description, :invite_in, :updated_at,
               :invite_date, :editor_id, :with_tokens, :token_value_map, :cc_with_tokens, 
               :bcc_with_tokens, :is_enabled, :is_default, :schedule_options, :template_edited_by

    has_many :attachments, serializer: AttachmentSerializer

    def cc
      object.get_cc(scope[:user])
    end

    def bcc
      object.get_bcc(scope[:user])
    end
    
    def description
      object.get_description(scope[:user])
    end

    def with_tokens
      object.description
    end

    def cc_with_tokens
      object.cc
    end

    def bcc_with_tokens
      object.bcc
    end

    def token_value_map
      object.get_token_values(scope[:user])
    end

    def subject
      object.get_subject(scope[:user])
    end

    def template_edited_by
      object.editor.present? ? object.editor.display_name : ''
    end
  end
end
