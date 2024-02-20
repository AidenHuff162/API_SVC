class HrisIntegrationsService::Bamboo::Doordash::ManageSaplingTabularData < HrisIntegrationsService::Bamboo::ManageSaplingTabularData
	
	def initialize(company)
		super(company)
		
  	@emergency_custom_fields = {
      name: 'Emergency Contact Name',
      homePhone: 'Emergency Contact Phone Number',
      mobilePhone: 'Emergency Contact Mobile Number',
      relationship: 'Emergency Contact Relationship'
    }
	end
end