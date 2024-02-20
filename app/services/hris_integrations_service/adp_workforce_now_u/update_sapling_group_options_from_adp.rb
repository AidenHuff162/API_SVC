class HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingGroupOptionsFromAdp
	attr_reader :company, :adp_wfn_api, :enviornment

	delegate :create_loggings, :fetch_adp_correlation_id_from_response, to: :helper
	delegate :fetch_code_lists, to: :events

	def initialize(adp_wfn_api)
		@adp_wfn_api = adp_wfn_api
		@company = adp_wfn_api&.company
		@enviornment = adp_wfn_api&.api_identifier&.split('_')&.last&.upcase
	end

	def sync
		return unless @company.subdomain != 'iqpc'

		configuration = HrisIntegrationsService::AdpWorkforceNowU::Configuration.new(adp_wfn_api)
		return unless configuration.adp_workforce_api_initialized? && enviornment.present? && ['US', 'CAN'].include?(enviornment)

    begin
      access_token = configuration.retrieve_access_token
    rescue Exception => e
      log(500, 'UpdateSaplingGroupOptionsFromAdp - Access Token Retrieval - ERROR', { message: e.message })
      return
		end

		begin
			certificate = configuration.retrieve_certificate
		rescue Exception => e
			log(500, 'UpdateSaplingGroupOptionsFromAdp - Certificate Retrieval - ERROR', { message: e.message })
		end

		return unless access_token.present? && certificate.present?

		sync_group_options(access_token, certificate)
	end

	private

	def sync_group_options(access_token, certificate)
		sync_location_option_and_codes(access_token, certificate)
		sync_department_option_and_codes(access_token, certificate)
		sync_business_unit_option_and_codes(access_token, certificate)
		sync_job_title_option_and_codes(access_token, certificate)
	end

	def sync_location_option_and_codes(access_token, certificate)
		data = fetch_data(company.location_mapping_key.downcase.pluralize, access_token, certificate)
		return unless data.present?
		sync_table_option_and_codes(data, 'Location', true)
		@adp_wfn_api.update_column(:synced_at, DateTime.now) if @adp_wfn_api
	end

	def sync_department_option_and_codes(access_token, certificate)
		data = fetch_data(company.department_mapping_key.downcase.pluralize, access_token, certificate)
		return unless data.present?

		sync_teams(data)
		
		company_codes = CustomFieldOption.joins(:custom_field).where(custom_fields: {name: 'ADP Company Code', company_id: company.id}).pluck(:option)
	  	company_codes.each do |company_code| 
	  	data = fetch_data(company.department_mapping_key.downcase.pluralize, access_token, certificate, company_code)
			next unless data.present?
			sync_teams(data, company_code)
		end
	end

	def sync_teams(data, company_code = nil)
		selected_data = company_code ? data.select { |department| department['foreignKey'] == company_code } : data.select { |department| department['foreignKey'] == fetch_company_code.try(:strip) || fetch_company_code.blank? }
		
		company_code ||= 'default'
		sync_table_option_and_codes(selected_data, 'Team', false, company_code)
		@adp_wfn_api.update_column(:synced_at, DateTime.now) if @adp_wfn_api
	end

	def sync_business_unit_option_and_codes(access_token, certificate)
		business_unit = CustomFieldsCollection.new(company_id: company.id, integration_group: 4, name: "Business Unit").results.take
		return unless business_unit.present?

		data = fetch_data(business_unit.mapping_key.to_s.gsub(/\s/, '-').downcase.pluralize, access_token, certificate)
		return unless data.present?

		sync_custom_field_option_and_codes(data, business_unit.id, true)
	end

	def sync_job_title_option_and_codes(access_token, certificate)
		data = fetch_data('job-titles', access_token, certificate)
		return unless data.present?

		sync_table_option_and_codes(data, 'JobTitle')
		@adp_wfn_api.update_column(:synced_at, DateTime.now) if @adp_wfn_api
	end

	def fetch_data(table_name, access_token, certificate, company_code = nil)
		begin
			response = fetch_code_lists(table_name, access_token, certificate, company_code)
			set_correlation_id(response)
			if response&.status == 200
				result = JSON.parse(response.body)

				::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
				return result['codeLists'][0]['listItems'] rescue []
			else
				log(response.status, "UpdateSaplingGroupOptionsFromAdp - #{table_name.titleize} - ERROR", { message: response.inspect })
				::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
			end
		rescue Exception => e
			log(500, "UpdateSaplingGroupOptionsFromAdp - #{table_name.titleize} - ERROR", { message: e.message })
			::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
		end

    return nil
	end

	def sync_table_option_and_codes(data, class_name, is_syncronized = false, company_code = 'default')
		updated_option_ids = []

		data.each do |meta_data|	
			if class_name == 'Team'
				option_id = class_name.constantize.sync_adp_option_and_code(company, (meta_data['shortName']&.strip || meta_data['longName']&.strip),
					meta_data['codeValue'], enviornment, company_code)
			else	
				option_id = class_name.constantize.sync_adp_option_and_code(company, (meta_data['shortName']&.strip || meta_data['longName']&.strip),
					meta_data['codeValue'], enviornment)
			end

			updated_option_ids.push(option_id) if is_syncronized
		end

		updated_option_ids = updated_option_ids&.reject(&:nil?)
		if updated_option_ids.present? && is_syncronized
			class_name.constantize.deactivate_adp_options(company, updated_option_ids, enviornment)
		end
	end

	def sync_custom_field_option_and_codes(data, field_id, is_syncronized = false)
		return unless data.present? && field_id.present?
		updated_option_ids = []

		data.each do |meta_data|
			option_id = CustomFieldOption.sync_adp_option_and_code(company, nil, (meta_data['shortName'] || meta_data['longName']),
				meta_data['codeValue'], enviornment, field_id)
			updated_option_ids.push(option_id) if is_syncronized
		end
		@adp_wfn_api.update_column(:synced_at, DateTime.now) if @adp_wfn_api

		updated_option_ids = updated_option_ids&.reject(&:nil?)
		if updated_option_ids.present? && is_syncronized
			CustomFieldOption.deactivate_adp_options(nil, company, updated_option_ids, enviornment, field_id)
		end
	end

	def fetch_company_code
		enviornment == 'US' ? company.adp_us_company_code : company.adp_can_company_code
	end

	def helper
		HrisIntegrationsService::AdpWorkforceNowU::Helper.new
	end

	def events
		HrisIntegrationsService::AdpWorkforceNowU::Events.new
	end

	def set_correlation_id(response)
	  @correlation_id = fetch_adp_correlation_id_from_response(response)
	end

	def log(status, action, result)
		create_loggings(company, "ADP Workforce Now - #{enviornment}", status, action, result.merge({adp_correlation_id: @correlation_id}))
	end
end
