class HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp
	attr_reader :company, :user, :adp_wfn_api, :enviornment

	delegate :initialize_adp_wfn_us, :initialize_adp_wfn_can, :can_integrate_profile?, :create_loggings, 
		:notify_slack, to: :helper_service

	def initialize(user)
		@user = user
		@company = user.company

		@adp_wfn_api = initialize_api_credentials
		@enviornment = adp_wfn_api&.api_identifier&.split('_')&.last&.upcase
	end

	def create
		unless adp_wfn_api.present? && enviornment.present? && ['US', 'CAN'].include?(enviornment)
			message = 'Either integration not initialized OR Integration apply to is not matched with the user data'

			log(404, 'Create Profile in ADP - Credentials Not Found - ERROR', 
				{ message: message })	
			notify_slack("*#{company.name}* tried to create #{user.full_name}'s (#{user.id}) profile in ADP but received error message that *#{message}*")
			
			return
		end

		return if @user.adp_wfn_us_id.present? || @user.adp_wfn_can_id.present?

		create_profile_service = HrisIntegrationsService::AdpWorkforceNowU::CreateSaplingProfileInAdp.new(user, adp_wfn_api, enviornment)
		create_profile_service.create
	end

	def update(field_name, value = nil, field_id = nil)
		return unless adp_wfn_api&.can_export_updation.present?

		unless adp_wfn_api.present? && enviornment.present? && ['US', 'CAN'].include?(enviornment)
			message = 'Either integration not initialized OR Integration apply to is not matched with the user data'

			log(404, 'Update Profile in ADP - Credentials Not Found - ERROR', 
				{ message: message })	
			notify_slack("*#{company.name}* tried to create #{user.full_name}'s (#{user.id}) profile in ADP but received error message that *#{message}*")
			
			return
		end

		return if (enviornment == 'US' && @user.adp_wfn_us_id.blank?) || (enviornment == 'CAN' && @user.adp_wfn_can_id.blank?)

		update_profile_service = HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingProfileInAdp.new(user, adp_wfn_api, enviornment)
		update_profile_service.update(field_name, value, field_id)
	end

	private

	def initialize_api_credentials
		adp_wfn_us_api = initialize_adp_wfn_us(company)
		return adp_wfn_us_api if can_integrate_profile?(adp_wfn_us_api, user)

		adp_wfn_can_api = initialize_adp_wfn_can(company)
		return adp_wfn_can_api if can_integrate_profile?(adp_wfn_can_api, user)
	end

	def helper_service
		HrisIntegrationsService::AdpWorkforceNowU::Helper.new
	end

	def log(status, action, result)
		create_loggings(company, "ADP Workforce Now - #{enviornment}", status, action, result)
	end
end
