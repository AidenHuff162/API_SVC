module CompanySerializer
  class CannyIdentifyCompany < ActiveModel::Serializer
  	attributes :id, :name, :created_at, :locations_count, :people_count, :users_count, :monthly_spend

  	def monthly_spend
  		object.salesforce_account&.mrr
  	end
  end
end