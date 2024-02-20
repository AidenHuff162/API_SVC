module DocumentSerializer
  class Dashboard < ActiveModel::Serializer
    attributes :id, :title, :doc_owners_count

    def doc_owners_count
      PaperworkRequest
        .where("(paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NUll)) AND paperwork_requests.document_id=?", object.id )
        .pluck("paperwork_requests.requester_id")
        .uniq
        .count
    end
  end
end
