module IndividualDocumentsSerializer
  class Full < ActiveModel::Serializer
    type :paperwork_template

    attributes :id, :user_id, :meta, :company_id, :title, :description,:updated_at,
               :preferred_name, :first_name, :last_name, :type, :location_ids, :department_ids,
               :status_ids, :document_id, :document_connection_relation_id, :global, 
               :special_user_id, :representative, :representative_pict, :is_manager_representative,
               :updated_by_preferred_name, :updated_by_first_name, :updated_by_last_name, :paperwork_request_co_signer_id,
               :hellosign_signature_request_id, :need_reset


    def read_attribute_for_serialization(attr)
      if object.key? attr.to_s
        attr.to_s == 'meta' ? JSON.parse(object['meta']) : object[attr.to_s]
      else
        self.send(attr) rescue nil
      end
    end

    def location_ids
      if meta_content && meta_content['location_id'] == ['all']
        ['all']
      elsif object['meta']
        meta_content['location_id'].reject(&:blank?)
      end
    end

    def document_connection_relation_id
      object['document_id']
    end

    def special_user_id
      object['specical_user']
    end

    def department_ids
      if meta_content && meta_content["team_id"] == ['all']
        ['all']
      elsif object['meta']
        meta_content['team_id'].reject(&:blank?)
      end
    end

    def status_ids
      if meta_content && meta_content["employee_type"] == ['all']
        ['all']
      elsif object['meta']
        meta_content['employee_type'].reject(&:blank?)
      end
    end

    def meta_content
      @meta ||= JSON.parse(object['meta'])
    end

    def representative
      PaperworkTemplate.get_representative_details(object) if (object['type'] == 0)
    end

    def representative_pict
      PaperworkTemplate.get_representative_details(object, true) if (object['type'] == 0)
    end

    def is_manager_representative
      object['is_manager_representative'].present? ? object['is_manager_representative'] : false
    end    
  end
end
