class HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingCustomFieldOptionsFromAdp
	attr_reader :company, :adp_wfn_api, :enviornment

	delegate :create_loggings, :fetch_adp_correlation_id_from_response, to: :helper
	delegate :fetch_worker_meta, to: :events

	def initialize(adp_wfn_api)
		@adp_wfn_api = adp_wfn_api
		@company = adp_wfn_api&.company
		@enviornment = adp_wfn_api&.api_identifier&.split('_')&.last&.upcase
	end

	def sync
		configuration = HrisIntegrationsService::AdpWorkforceNowU::Configuration.new(adp_wfn_api)
		return unless configuration.adp_workforce_api_initialized? && enviornment.present? && ['US', 'CAN'].include?(enviornment)

		begin
			access_token = configuration.retrieve_access_token
		rescue Exception => e
			log(500, 'UpdateSaplingFieldOptionsFromAdp - Access Token Retrieval - ERROR', { message: e.message })
			return
		end

		begin
			certificate = configuration.retrieve_certificate
		rescue Exception => e
			log(500, 'UpdateSaplingFieldOptionsFromAdp - Certificate Retrieval - ERROR', { message: e.message })
		end

		return unless access_token.present? && certificate.present?

		sync_custom_field_options(access_token, certificate)
	end

	private

	def sync_custom_field_options(access_token, certificate)
		begin
			response = fetch_worker_meta(access_token, certificate)
			set_correlation_id(response)

			if response&.status == 200
				meta = JSON.parse(response.body)

				sync_federal_marital_status_option_and_codes(meta)
				sync_gender_option_and_codes(meta)
				sync_race_id_method_option_and_codes(meta)
				sync_ethnicity_option_and_codes(meta)
				sync_employment_status_option_and_codes(meta)
				sync_pay_frequency_option_and_codes(meta)
				# sync_job_title_option_and_codes(meta)
				sync_rate_type_option_and_codes
				::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
				@adp_wfn_api.update_column(:synced_at, DateTime.now) if @adp_wfn_api
			else
				log(response.status, "UpdateSaplingCustomFieldOptionsFromAdp - IntegrationMetadata - ERROR", { message: response.inspect })
				::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
			end
		rescue Exception => e
			log(500, 'UpdateSaplingCustomFieldOptionsFromAdp IntegrationMetadata - ERROR', { message: e.message })
			::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
		end
	end

	def sync_federal_marital_status_option_and_codes(data)
		meta = data['meta']['/workers/person/maritalStatusCode']['codeList']['listItems'] rescue []
		sync_custom_field_option_and_codes(meta, 'Federal Marital Status')
	end

	def sync_gender_option_and_codes(data)
		meta = data['meta']['/workers/person/genderCode']['codeList']['listItems'] rescue []
		sync_custom_field_option_and_codes(meta, 'Gender')
	end

	def sync_race_id_method_option_and_codes(data)
		meta = data['meta']['/workers/person/raceCode/identificationMethodCode']['codeList']['listItems'] rescue []
		sync_custom_field_option_and_codes(meta, 'Race ID Method')
	end

	def sync_ethnicity_option_and_codes(data)
		meta = data['meta']['/workers/person/raceCode']['codeList']['listItems'] rescue []
		sync_custom_field_option_and_codes(meta, 'Race/Ethnicity')
	end

	def sync_employment_status_option_and_codes(data)
		meta = data['meta']['/workers/workAssignments/workerTypeCode']['codeList']['listItems'] rescue []
		sync_custom_field_option_and_codes(meta, 'Employment Status', company.domain != 'shift.saplingapp.io')
	end

	def sync_pay_frequency_option_and_codes(data)
		meta = data['meta']['/workers/workAssignments/payCycleCode']['codeList']['listItems'] rescue []
		sync_custom_field_option_and_codes(meta, 'Pay Frequency')
	end

	def sync_rate_type_option_and_codes
		if enviornment == 'US'
			meta = [ {'shortName' => 'Hourly', 'codeValue' => 'H'}, {'shortName' => 'Daily', 'codeValue' => 'D'}, {'shortName' => 'Salary', 'codeValue' => 'S'} ]
		else
			meta = [ {'shortName' => 'Hourly', 'codeValue' => 'Hourly'}, {'shortName' => 'Daily', 'codeValue' => 'Daily'}, {'shortName' => 'Salary', 'codeValue' => 'Salary'},
			 {'shortName' => 'Variable', 'codeValue' => 'Variable'}, {'shortName' => 'Exception Hourly', 'codeValue' => 'Exception Hourly'}, {'shortName' => 'Commission', 'codeValue' => 'Commission'},
			 {'shortName' => 'Salary + Commission', 'codeValue' => 'Salary + Commission'} ]
		end
		sync_custom_field_option_and_codes(meta, 'Rate Type')
	end

	def sync_custom_field_option_and_codes(data, field_name, is_syncronized = false)
		return unless data.present? && field_name.present?
		updated_option_ids = []
		data.each do |meta_data|
			option_id = CustomFieldOption.sync_adp_option_and_code(company, field_name, (meta_data['shortName'] || meta_data['longName']),
				meta_data['codeValue'], enviornment)
			updated_option_ids.push(option_id) if is_syncronized
		end

		updated_option_ids = updated_option_ids&.reject(&:nil?)
		if updated_option_ids.present? && is_syncronized
			CustomFieldOption.deactivate_adp_options(field_name, company, updated_option_ids, enviornment, nil)
		end
	end

	def sync_job_title_option_and_codes(data)
		meta = data['meta']['/workers/workAssignments/jobCode']['codeList']['listItems'] rescue []
		return unless meta.present?

		meta.each do |meta_data|
			JobTitle.sync_adp_option_and_code(company, (meta_data['shortName'] || meta_data['longName']),
				meta_data['codeValue'], enviornment)
		end
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
