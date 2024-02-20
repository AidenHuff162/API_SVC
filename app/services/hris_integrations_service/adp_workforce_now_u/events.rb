class HrisIntegrationsService::AdpWorkforceNowU::Events
	BASE_URL = 'https://api.adp.com/'

	def fetch_worker_meta(access_token, certificate)
		get('hr/v2/workers/meta', access_token, certificate)
	end

	def applicant_onboard_meta(access_token, certificate)
		get('events/staffing/v1/applicant.onboard/meta', access_token, certificate)
	end

	def fetch_code_lists(table_name, access_token, certificate, company_code = nil)
		company_code ? get("codelists/hr/v3/worker-management/#{table_name}/WFN/1?$filter=foreignKey eq '#{company_code}'", access_token, certificate) : get("codelists/hr/v3/worker-management/#{table_name}/WFN/1", access_token, certificate)
	end

	def applicant_onboard(params, access_token, certificate)
		post('events/staffing/v1/applicant.onboard', access_token, certificate, params)
	end

	def applicant_onboard_v2(params, access_token, certificate)
		post('hcm/v2/applicant.onboard', access_token, certificate, params)
	end

	def change_ethnicity(params, access_token, certificate)
		post('events/hr/v1/worker.ethnicity.change', access_token, certificate, params)
	end

 	def change_race(params, access_token, certificate)
		post('events/hr/v1/worker.race.change', access_token, certificate, params)
	end

 	def change_gender(params, access_token, certificate)
		post('events/hr/v1/worker.gender.change', access_token, certificate, params)
	end

 	def change_middle_name(params, access_token, certificate)
		post('events/hr/v1/worker.legal-name.change', access_token, certificate, params)
	end

	def change_preferred_name(params, access_token, certificate)
		post('events/hr/v1/worker.preferred-name.change', access_token, certificate, params)
	end

 	def change_marital_status(params, access_token, certificate)
		post('events/hr/v1/worker.marital-status.change', access_token, certificate, params)
	end

 	def change_business_communication_email(params, access_token, certificate)
		post('events/hr/v1/worker.business-communication.email.change', access_token, certificate, params)
	end

 	def change_personal_communication_email(params, access_token, certificate)
		post('events/hr/v1/worker.personal-communication.email.change', access_token, certificate, params)
	end

 	def change_personal_communication_landline(params, access_token, certificate)
		post('events/hr/v1/worker.personal-communication.landline.change', access_token, certificate, params)
	end

 	def change_personal_communication_mobile(params, access_token, certificate)
		post('events/hr/v1/worker.personal-communication.mobile.change', access_token, certificate, params)
	end

 	def change_worker_string_custom_field(params, access_token, certificate)
		post('events/hr/v1/worker.custom-field.string.change', access_token, certificate, params)
	end

	def change_legal_address(params, access_token, certificate)
		post('events/hr/v1/worker.legal-address.change', access_token, certificate, params)
	end
	
	def change_base_remunration(params, access_token, certificate)
		post('events/hr/v1/worker.work-assignment.base-remuneration.change', access_token, certificate, params)
	end

	def fetch_notification_message(access_token, certificate)
		get("core/v1/event-notification-messages", access_token, certificate, {:accept => 'application/json', role_code: 'practitioner', prefer: '/adp/long-polling'})
	end

	def delete_notification_message(access_token, certificate, event_notification_id)
		delete("core/v1/event-notification-messages/#{event_notification_id}", access_token, certificate)
	end

	def fetch_worker(access_token, certificate, adp_wfn_id)
		get("hr/v2/workers/#{adp_wfn_id}", access_token, certificate)
	end

	def fetch_workers(access_token, certificate, skip)
		get("hr/v2/workers?$top=100&$skip=#{skip}", access_token, certificate)
	end

	def fetch_onboarding_templates(access_token, certificate)
		get("codelists/hr/v3/position-seeker-management/applicant-onboard-templates/WFN/1", access_token, certificate)	
	end

	def fetch_company_codes(access_token, certificate)
		get('events/staffing/v1/applicant.onboard/meta', access_token, certificate)
	end

	def change_string_custom_field(params, access_token, certificate)
		post('events/hr/v1/worker.custom-field.string.change', access_token, certificate, params)
	end

	def change_manager(params, access_token, certificate) 
		post('events/hr/v1/worker.reports-to.modify', access_token, certificate, params)
	end

	def fetch_v2_onboarding_templates(access_token, certificate, identifier = 'US') get('hcm/v2/applicant.onboard/meta', access_token, certificate, {'Content-Type': 'application/json', 'ADP-Context-ExpressionID': "country=#{identifier}"}) end

	def terminate_employee(params, access_token, certificate)
		post('events/hr/v1/worker.work-assignment.terminate', access_token, certificate, params)
	end

	def rehire_employee(params, access_token, certificate)
		post('events/hr/v1/worker.rehire', access_token, certificate, params)
	end

	private

	def get(event_url, access_token, certificate, headers = {'Content-Type': 'application/json'})
		faraday_connection_adapter(certificate).get "#{event_url}" do |req|
		  req.headers = headers
		  req.headers['authorization'] = "Bearer #{access_token}"
		end
	end

	def post(event_url, access_token, certificate, data)
		faraday_connection_adapter(certificate).post "#{event_url}" do |req|
		  req.headers['Content-Type'] = 'application/json'
		  req.headers['authorization'] = "Bearer #{access_token}"
		  req.body = data.to_json
		end
	end

	def delete(event_url, access_token, certificate)
		faraday_connection_adapter(certificate).delete "#{event_url}" do |req|
		  req.headers['Content-Type'] = 'application/json'
		  req.headers['authorization'] = "Bearer #{access_token}"
		end
	end

	def faraday_connection_adapter(certificate)
		Faraday.new "#{BASE_URL}", :ssl => {
		  :client_cert  => certificate&.cert,
		  :client_key   => certificate&.key,
	  }
	end
end