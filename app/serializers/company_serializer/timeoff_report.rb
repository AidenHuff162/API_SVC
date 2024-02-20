module CompanySerializer
  class TimeoffReport < ActiveModel::Serializer
    attributes :prefrences, :company_pto_policies_ids, :company_plan

    def company_pto_policies_ids
    	object.pto_policies.ids if object.pto_policies.present?
    end

  end
end
