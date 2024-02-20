class HrisIntegrationsService::Bamboo::Doordash::ManageSaplingSingleDimensionData < HrisIntegrationsService::Bamboo::ManageSaplingSingleDimensionData
	attr_reader :company

	def initialize(company)
		super(company)
		custom_fields.merge!({
      maritalStatus: 'marital status'
		})
	end
end