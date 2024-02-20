class HandleBulkHellosignCallService
	attr_reader :hellosign_call, :paperwork_template

	def initialize(hellosign_call, paperwork_templates)
		@hellosign_call = hellosign_call
    @paperwork_templates = paperwork_templates
	end

	def perform
    handle_create_embedded_bulk_send_with_template
	end

	private
  
  def handle_create_embedded_bulk_send_with_template
    template_ids = []
    merge_fields = []
    @paperwork_templates.each do |paperwork_template|
  		begin
        template_ids.push paperwork_template.hellosign_template_id
  		  request = HelloSign.get_template(template_id: paperwork_template.hellosign_template_id)
      #:nocov:
      rescue Net::ReadTimeout => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: 'N/A', error_name: 'Server ReadTimeout', error: e.message, error_category: HellosignCall.error_categories[:sapling], hellosign_call_id: @hellosign_call.id })
        return
      rescue HelloSign::Error::MissingAttributes => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: 'N/A', error_name: 'MissingAttributes', error: e.message, error_category: HellosignCall.error_categories[:sapling], hellosign_call_id: @hellosign_call.id })
        @hellosign_call.update(state: HellosignCall.states[:failed], error_code: 'N/A', error_name: 'MissingAttributes', error_description: e.message, error_category: HellosignCall.error_categories[:sapling])
        PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
        return
      rescue HelloSign::Error::MissingCredentials => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: 'N/A', error_name: 'MissingCredentials', error: e.message, error_category: HellosignCall.error_categories[:sapling], hellosign_call_id: @hellosign_call.id })
        @hellosign_call.update(state: HellosignCall.states[:failed], error_code: 'N/A', error_name: 'MissingCredentials', error_description: e.message, error_category: HellosignCall.error_categories[:sapling])
        PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
        return
      rescue HelloSign::Error::Parsing => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: 'N/A', error_name: 'Parsing', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
        @hellosign_call.update(state: HellosignCall.states[:failed], error_code: 'N/A', error_name: 'Parsing', error_description: e.message, error_category: HellosignCall.error_categories[:hellosign])
        PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
        return
      rescue HelloSign::Error::BadRequest => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: '400', error_name: 'BadRequest', error: e.message, error_category: HellosignCall.error_categories[:user_sapling], hellosign_call_id: @hellosign_call.id })
        @hellosign_call.update(state: HellosignCall.states[:failed], error_code: '400', error_name: 'bad_request', error_description: e.message, error_category: HellosignCall.error_categories[:user_sapling])
        PaperworkRequest.bulk_fail_paperwork_request_email(true, @hellosign_call, 'bad_request')
        return
      rescue HelloSign::Error::Unauthorized => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: '401', error_name: 'Unauthorized', error: e.message, error_category: HellosignCall.error_categories[:sapling], hellosign_call_id: @hellosign_call.id })
        @hellosign_call.update(state: HellosignCall.states[:failed], error_code: '401', error_name: 'unauthorized', error_description: e.message, error_category: HellosignCall.error_categories[:sapling])
        PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
        return
      rescue HelloSign::Error::PaidApiPlanRequired => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: '402', error_name: 'PaidApliPlanRequired', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
        return
      rescue HelloSign::Error::Forbidden => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: '403', error_name: 'Forbidden', error: e.message, error_category: HellosignCall.error_categories[:sapling], hellosign_call_id: @hellosign_call.id })
        @hellosign_call.update(state: HellosignCall.states[:failed], error_code: '403', error_name: 'Forbidden', error_description: e.message, error_category: HellosignCall.error_categories[:sapling])
        PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
        return      
      rescue HelloSign::Error::NotFound => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: '404', error_name: 'NotFound', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
        @hellosign_call.update(state: HellosignCall.states[:failed], error_code: '404', error_name: 'NotFound', error_description: e.message, error_category: HellosignCall.error_categories[:hellosign])
        PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
        return
      rescue HelloSign::Error::MethodNotAllowed => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: '405', error_name: 'MethodNotAllowed', error: e.message, error_category: HellosignCall.error_categories[:sapling], hellosign_call_id: @hellosign_call.id })
        @hellosign_call.update(state: HellosignCall.states[:failed], error_code: '405', error_name: 'MethodNotAllowed', error_description: e.message, error_category: HellosignCall.error_categories[:sapling])
        PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
        return      
      rescue HelloSign::Error::Conflict => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: '409', error_name: 'Conflict', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
        return
      rescue HelloSign::Error::Gone => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: '410', error_name: 'Gone', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
        @hellosign_call.update(state: HellosignCall.states[:failed], error_code: '410', error_name: 'Gone', error_description: e.message, error_category: HellosignCall.error_categories[:hellosign])
        PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
        return
      rescue HelloSign::Error::InternalServerError => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: '500', error_name: 'InternalServerError', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
        return
      rescue HelloSign::Error::ExceededRate => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: '403', error_name: 'ExceededRate', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
        return
      rescue HelloSign::Error::BadGateway => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: '502', error_name: 'BadGateway', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
        return
      rescue HelloSign::Error::ServiceUnavailable => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: '503', error_name: 'ServiceUnavailable', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
        return
      rescue HelloSign::Error::NotSupportedType => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: '503', error_name: 'NotSupportedType', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
        @hellosign_call.update(state: HellosignCall.states[:failed], error_code: '503', error_name: 'NotSupportedType', error_description: e.message, error_category: HellosignCall.error_categories[:hellosign])
        PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
        return
      rescue HelloSign::Error::FileNotFound => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: 'N/A', error_name: 'FileNotFound', error: e.message, error_category: HellosignCall.error_categories[:user_sapling], hellosign_call_id: @hellosign_call.id })
        @hellosign_call.update(state: HellosignCall.states[:failed], error_code: 'N/A', error_name: 'FileNotFound', error_description: e.message, error_category: HellosignCall.error_categories[:user_sapling])
        PaperworkRequest.bulk_fail_paperwork_request_email(true, @hellosign_call, 'file_not_found')
        return
      rescue HelloSign::Error::UnknownError => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: 'N/A', error_name: 'UnknownError', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
        @hellosign_call.update(state: HellosignCall.states[:failed], error_code: 'N/A', error_name: 'UnknownError', error_description: e.message, error_category: HellosignCall.error_categories[:hellosign])
        PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
        return
      rescue Exception => e
        create_general_logging(@hellosign_call.company, 'Get template from Hellosign', { error_code: 'N/A', error_name: 'N/A', error: e.message, error_category: HellosignCall.error_categories[:user_sapling], hellosign_call_id: @hellosign_call.id })
        @hellosign_call.update(state: HellosignCall.states[:failed], error_code: 'N/A', error_name: 'N/A', error_description: e.message, error_category: HellosignCall.error_categories[:user_sapling])
        PaperworkRequest.bulk_fail_paperwork_request_email(true, @hellosign_call, 'other_exception')
        return
      end
      #:nocov:
      
  		merge_fields << [request.data['custom_fields']]
    end

    signer_roles = get_bulk_signer_roles(@hellosign_call.bulk_paperwork_requests, merge_fields)
    if signer_roles.blank?
      @hellosign_call.update(state: HellosignCall.states[:failed], error_code: 'N/A', error_name: 'N/A', error_description: 'Signer roles list is empty', error_category: HellosignCall.error_categories[:user_sapling])
      return
    end
    
    begin
      if @paperwork_templates.count == 1
        request = HelloSign.embedded_bulk_send_with_template(
          test_mode: @hellosign_call.company.get_hellosign_test_mode,
          client_id: Sapling::Application::HELLOSIGN_CLIENT_ID,
          template_id: template_ids.first,
          subject: @paperwork_templates.first.document.title,
          message: @paperwork_templates.first.document.description,
          signer_list: signer_roles)
      else
        request = HelloSign.embedded_bulk_send_with_template(
          test_mode: @hellosign_call.company.get_hellosign_test_mode,
          client_id: Sapling::Application::HELLOSIGN_CLIENT_ID,
          template_ids: template_ids,
          subject: @paperwork_templates.first.document.title,
          message: @paperwork_templates.first.document.description,
          signer_list: signer_roles)
      end
    #:nocov:
    rescue Net::ReadTimeout => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: 'N/A', error_name: 'Server ReadTimeout', error: e.message, error_category: HellosignCall.error_categories[:sapling], hellosign_call_id: @hellosign_call.id })
      return
    rescue HelloSign::Error::MissingAttributes => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: 'N/A', error_name: 'MissingAttributes', error: e.message, error_category: HellosignCall.error_categories[:sapling], hellosign_call_id: @hellosign_call.id })
      @hellosign_call.update(state: HellosignCall.states[:failed], error_code: 'N/A', error_name: 'MissingAttributes', error_description: e.message, error_category: HellosignCall.error_categories[:sapling])
      PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
      return
    rescue HelloSign::Error::MissingCredentials => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: 'N/A', error_name: 'MissingCredentials', error: e.message, error_category: HellosignCall.error_categories[:sapling], hellosign_call_id: @hellosign_call.id })
      @hellosign_call.update(state: HellosignCall.states[:failed], error_code: 'N/A', error_name: 'MissingCredentials', error_description: e.message, error_category: HellosignCall.error_categories[:sapling])
      PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
      return
    rescue HelloSign::Error::Parsing => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: 'N/A', error_name: 'Parsing', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
      @hellosign_call.update(state: HellosignCall.states[:failed], error_code: 'N/A', error_name: 'Parsing', error_description: e.message, error_category: HellosignCall.error_categories[:hellosign])
      PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
      return
    rescue HelloSign::Error::BadRequest => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: '400', error_name: 'BadRequest', error: e.message, error_category: HellosignCall.error_categories[:user_sapling], hellosign_call_id: @hellosign_call.id })
      @hellosign_call.update(state: HellosignCall.states[:failed], error_code: '400', error_name: 'bad_request', error_description: e.message, error_category: HellosignCall.error_categories[:user_sapling])
      PaperworkRequest.bulk_fail_paperwork_request_email(true, @hellosign_call, 'bad_request')
      return
    rescue HelloSign::Error::Unauthorized => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: '401', error_name: 'Unauthorized', error: e.message, error_category: HellosignCall.error_categories[:sapling], hellosign_call_id: @hellosign_call.id })
      @hellosign_call.update(state: HellosignCall.states[:failed], error_code: '401', error_name: 'unauthorized', error_description: e.message, error_category: HellosignCall.error_categories[:sapling])
      PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
      return
    rescue HelloSign::Error::PaidApiPlanRequired => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: '402', error_name: 'PaidApliPlanRequired', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
      return
    rescue HelloSign::Error::Forbidden => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: '403', error_name: 'Forbidden', error: e.message, error_category: HellosignCall.error_categories[:sapling], hellosign_call_id: @hellosign_call.id })
      @hellosign_call.update(state: HellosignCall.states[:failed], error_code: '403', error_name: 'Forbidden', error_description: e.message, error_category: HellosignCall.error_categories[:sapling])
      PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
      return      
    rescue HelloSign::Error::NotFound => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: '404', error_name: 'NotFound', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
      @hellosign_call.update(state: HellosignCall.states[:failed], error_code: '404', error_name: 'NotFound', error_description: e.message, error_category: HellosignCall.error_categories[:hellosign])
      PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
      return
    rescue HelloSign::Error::MethodNotAllowed => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: '405', error_name: 'MethodNotAllowed', error: e.message, error_category: HellosignCall.error_categories[:sapling], hellosign_call_id: @hellosign_call.id })
      @hellosign_call.update(state: HellosignCall.states[:failed], error_code: '405', error_name: 'MethodNotAllowed', error_description: e.message, error_category: HellosignCall.error_categories[:sapling])
      PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
      return      
    rescue HelloSign::Error::Conflict => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: '409', error_name: 'Conflict', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
      return
    rescue HelloSign::Error::Gone => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: '410', error_name: 'Gone', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
      @hellosign_call.update(state: HellosignCall.states[:failed], error_code: '410', error_name: 'Gone', error_description: e.message, error_category: HellosignCall.error_categories[:hellosign])
      PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
      return
    rescue HelloSign::Error::InternalServerError => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: '500', error_name: 'InternalServerError', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
      return
    rescue HelloSign::Error::ExceededRate => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: '403', error_name: 'ExceededRate', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
      return
    rescue HelloSign::Error::BadGateway => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: '502', error_name: 'BadGateway', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
      return
    rescue HelloSign::Error::ServiceUnavailable => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: '503', error_name: 'ServiceUnavailable', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
      return
    rescue HelloSign::Error::NotSupportedType => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: '503', error_name: 'NotSupportedType', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
      @hellosign_call.update(state: HellosignCall.states[:failed], error_code: '503', error_name: 'NotSupportedType', error_description: e.message, error_category: HellosignCall.error_categories[:hellosign])
      PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
      return
    rescue HelloSign::Error::FileNotFound => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: 'N/A', error_name: 'FileNotFound', error: e.message, error_category: HellosignCall.error_categories[:user_sapling], hellosign_call_id: @hellosign_call.id })
      @hellosign_call.update(state: HellosignCall.states[:failed], error_code: 'N/A', error_name: 'FileNotFound', error_description: e.message, error_category: HellosignCall.error_categories[:user_sapling])
      PaperworkRequest.bulk_fail_paperwork_request_email(true, @hellosign_call, 'file_not_found')
      return
    rescue HelloSign::Error::UnknownError => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: 'N/A', error_name: 'UnknownError', error: e.message, error_category: HellosignCall.error_categories[:hellosign], hellosign_call_id: @hellosign_call.id })
      @hellosign_call.update(state: HellosignCall.states[:failed], error_code: 'N/A', error_name: 'UnknownError', error_description: e.message, error_category: HellosignCall.error_categories[:hellosign])
      PaperworkRequest.bulk_fail_paperwork_request_email(false, @hellosign_call)
      return
    rescue Exception => e
      create_general_logging(@hellosign_call.company, 'Create bulk signature requests based off a template or templates', { error_code: 'N/A', error_name: 'N/A', error: e.message, error_category: HellosignCall.error_categories[:user_sapling], hellosign_call_id: @hellosign_call.id })
      @hellosign_call.update(state: HellosignCall.states[:failed], error_code: 'N/A', error_name: 'N/A', error_description: e.message, error_category: HellosignCall.error_categories[:user_sapling])
      PaperworkRequest.bulk_fail_paperwork_request_email(true, @hellosign_call, 'other_exception')
      return
    end
    #:nocov:
    if request.present? && request.data.present?
      HellosignCall.create_bulk_send_job_information(request.data['bulk_send_job_id'], @hellosign_call.company_id, @hellosign_call.bulk_paperwork_requests, @hellosign_call.assign_now, @hellosign_call.job_requester_id)
      @hellosign_call.update(state: HellosignCall.states[:completed])
    end
	end

	def get_bulk_signer_roles(bulk_paperwork_requests, merge_fields)
  	signers = []
  	bulk_paperwork_requests.each do |bulk_paperwork_request|
  		paperwork_request = PaperworkRequest.find_by(id: bulk_paperwork_request['paperwork_request_id'])
      next if !paperwork_request.present? || paperwork_request.draft? || !paperwork_request.user.present?
      custom_fields = {}
      merge_fields.each do |merge_field|
        merge_field.first.each do |custom_field|
          custom_fields[custom_field.data['name']] = paperwork_request.merge_field_value(custom_field.data['name'])
        end
      end
      signers << {
  			signers: {
  				employee: {
  					email_address: paperwork_request.user.email || paperwork_request.user.personal_email,
  					name: paperwork_request.user.full_name,
  					order: 0
  				}
  			},
        custom_fields: custom_fields
  		}
  	end
    signers
  end

  def create_general_logging(company, action, data, type = 'Overall')
    @general_logging ||= LoggingService::GeneralLogging.new
    @general_logging.create(company, action, data, type)
  end
end
