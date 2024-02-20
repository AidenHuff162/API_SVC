module Api
  module V1
    module Admin
      module WebhookIntegrations
        class LeverController < WebhookController
          require 'openssl'

          before_action :lever_credentials, only: [:create]
          before_action :convert_params_to_hash, only: [:create]


          #TODO: Have to remove sandbox from URLs after testing and have to uncomment x_lever_client_id
          def create
            webhook_executed = 'failed'
            message = nil
            error = nil
            
            begin
              if current_company.lever_mapping_feature_flag
                return unless @lever_api_instances.present?
                
                @helper = initialize_helper()
                @lever_api = @helper.fetch_and_verify_webhook(params, @lever_api_instances)
                
                if @lever_api.present?
                  @api_key =  @lever_api.api_key rescue nil
                  @lever_api.in_progress!
                  
                  opportunity_id = params[:data][:opportunityId]
                  if opportunity_id.present?
                    webhook_executed = AtsIntegrationsService::Lever::ManageLeverProfileInSapling.new.fetch_lever_sections_data(@lever_api, opportunity_id, @api_key, current_company)
                  end
                  current_company.update(is_recruitment_system_integrated: true) unless current_company.is_recruitment_system_integrated?

                  log_success_webhook_statistics(current_company)
                end
              else
                @opportunities_base_url = 'https://api.lever.co/v1/opportunities/'
                @opportunities_base_url = 'https://api.sandbox.lever.co/v1/opportunities/' if Rails.env.staging?
                @api_key =  @lever_api.api_key rescue nil
                @signature_token = @lever_api.signature_token rescue nil

                if verify_webhook?(params)
                  opportunity_id = params[:data][:opportunityId]
                  if opportunity_id.present?
                    lever_webhook_resource = RestClient::Resource.new "#{@opportunities_base_url}#{opportunity_id}", "#{@api_key}", ''
                    if Rails.env.staging?
                      hired_candidate = JSON.parse(lever_webhook_resource.get())
                    else
                      hired_candidate = JSON.parse(lever_webhook_resource.get({x_lever_client_id: ENV['LEVER_X_CLIENT_ID']}))
                    end

                    application = get_hired_candidate_application(opportunity_id) rescue {}
                    hired_candidate_profile_form_fields = get_hired_candidate_form_fields(opportunity_id) rescue []
                    offer_data = get_candidate_offer_data(opportunity_id) rescue {}
                    
                    hired_candidate_posting = {}
                    hired_candidate_manager = {}
                    hired_candidate_requisition = {}
                    
                    if application.present?
                      hired_candidate_posting = get_candidate_posting_data(application[:posting]) if application[:posting].present?
                      
                      if offer_data.present? && offer_data["fields"].present? && ['toptal', 'lyra'].include?(current_company.subdomain) 
                        manager_id = nil
                        offer_data["fields"].select{|field| manager_id = field["value"] if field["identifier"] == "hiring_manager" } 
                        hired_candidate_manager = get_candidate_posting_manager(manager_id) if manager_id.present?
                      elsif application[:postingHiringManager].present?
                        hired_candidate_manager = get_candidate_posting_manager(application[:postingHiringManager]) 
                      end
                      
                      hired_candidate_requisition = get_candidate_requisition(application[:requisition_id]) if application[:requisition_id].present?
                    end

                    referral_data = nil
                    if hired_candidate['data'] && hired_candidate['data']['sources'] && hired_candidate['data']['sources'][0] == "Referral"
                      referral_data = get_referral_data(opportunity_id)
                    end

                    PendingHire.create_by_lever(hired_candidate['data'], hired_candidate_posting, hired_candidate_manager, hired_candidate_profile_form_fields, current_company, offer_data, referral_data, hired_candidate_requisition) if hired_candidate['data'].present?
                    webhook_executed = 'succeed'
                  end
                  current_company.update(is_recruitment_system_integrated: true) unless current_company.is_recruitment_system_integrated?

                  log_success_webhook_statistics(current_company)
                end
              end
            rescue Exception => exception
              @lever_api.failed! if current_company.lever_mapping_feature_flag
              log_failed_webhook_statistics(current_company)
              error = exception.message
              webhook_executed = 'failed'
              comapny_name = current_company ? current_company.name : 'Unknown'
              message = "The #{comapny_name} has failed to pull data for Lever with exception #{exception}. We received #{params.to_json}"
              params.merge!({error: exception})
            ensure
              resp_data = params.to_hash
              company_id = current_company ? current_company.id : nil
              if current_company.lever_mapping_feature_flag
                @lever_api.update_column(:synced_at, DateTime.now) if @lever_api
                @lever_api.update_columns(sync_status: IntegrationInstance.sync_statuses[:succeed], synced_at: DateTime.now) if @lever_api
              else
                resp_data.merge!({"***************" => hired_candidate}) if hired_candidate.present?
                @lever_api.update_column(:last_sync, DateTime.now) if @lever_api
              end

              create_webhook_logging(current_company, 'Lever', 'Create', resp_data, webhook_executed, 'LeverController/create', error)

              ::IntegrationErrors::SendIntegrationErrorNotificationToSlackJob.perform_now(message,
                  IntegrationErrorSlackWebhook.integration_types.key(IntegrationErrorSlackWebhook.integration_types[:applicant_tracking_system])) if message.present?
            end
            return render json: true
          end

          private

          def initialize_helper()
            AtsIntegrationsService::Lever::Helper.new()
          end
          
          def verify_webhook?(lever_params)
            return false if !@signature_token.present?

            lever_token = lever_params['token'].to_s rescue nil
            lever_triggered_at = params['triggeredAt'].to_s rescue nil
            lever_signature = params['signature'].to_s rescue nil

            return false if !lever_token.present? || !lever_triggered_at.present? || !lever_signature.present?

            data = lever_token + lever_triggered_at
            digest = OpenSSL::Digest.new('sha256')
            generated_signature = OpenSSL::HMAC.hexdigest digest, @signature_token, data
            generated_signature.to_s.eql?(lever_signature) if generated_signature.present?
          end

          def get_hired_candidate_application(opportunity_id)
            hired_archive_reason = get_hired_archive_reason
            lever_application_resource = RestClient::Resource.new "#{@opportunities_base_url}#{opportunity_id}/applications", "#{@api_key}", ''
            if Rails.env.staging?
              applications = JSON.parse(lever_application_resource.get())
            else
              applications = JSON.parse(lever_application_resource.get({x_lever_client_id: ENV['LEVER_X_CLIENT_ID']}))
            end

            applications['data'].try(:each) do |application|
              application_archived_reason = application['archived']['reason'] rescue nil
              if application_archived_reason.present? && application_archived_reason.eql?(hired_archive_reason)
                posting = application['posting'] rescue nil
                postingHiringManager =  application['postingHiringManager'] rescue nil
                requisition_id = application['requisitionForHire']['id'] rescue nil
                return {posting: posting, postingHiringManager: postingHiringManager, requisition_id: requisition_id}
              end
            end

            return nil
          end

          def get_hired_candidate_form_fields(opportunity_id)

            form_resource = RestClient::Resource.new "#{@opportunities_base_url}#{opportunity_id}/forms", "#{@api_key}", ''
            if Rails.env.staging?
              forms = JSON.parse(form_resource.get())
            else
              forms = JSON.parse(form_resource.get({x_lever_client_id: ENV['LEVER_X_CLIENT_ID']}))
            end

            form_fields = []
            if forms.present?
              forms['data'].try(:each) do |form|
                form_fields.concat(form['fields']) if form['fields'].present? && form['fields'].count > 1
              end
            end

            return form_fields
          end

          def get_candidate_posting_data(posting_id)
            postings_base_url = 'https://api.lever.co/v1/postings/'
            postings_base_url = 'https://api.sandbox.lever.co/v1/postings/' if Rails.env.staging?
            lever_posting_resource = RestClient::Resource.new "#{postings_base_url}#{posting_id}", "#{@api_key}", ''
            if Rails.env.staging?
              hired_candidate_posting = JSON.parse(lever_posting_resource.get())
            else
              hired_candidate_posting = JSON.parse(lever_posting_resource.get({x_lever_client_id: ENV['LEVER_X_CLIENT_ID']}))
            end

            hired_candidate_posting['data'] rescue nil
          end

          def get_hired_archive_reason
            archive_reason_base_url = "https://api.lever.co/v1/archive_reasons?type=hired"
            archive_reason_base_url = "https://api.sandbox.lever.co/v1/archive_reasons?type=hired" if Rails.env.staging?

            lever_arhive_reason_resource = RestClient::Resource.new "#{archive_reason_base_url}", "#{@api_key}", ''
            if Rails.env.staging?
              archive_reason = JSON.parse(lever_arhive_reason_resource.get())
            else
              archive_reason = JSON.parse(lever_arhive_reason_resource.get({x_lever_client_id: ENV['LEVER_X_CLIENT_ID']}))
            end
            
            archive_reason['data'][0]['id'] rescue nil
          end

          def get_candidate_posting_manager(posting_hiring_manager_id)
            user_base_url = 'https://api.lever.co/v1/users/'
            user_base_url = 'https://api.sandbox.lever.co/v1/users/' if Rails.env.staging?          
            lever_user_resource = RestClient::Resource.new "#{user_base_url}#{posting_hiring_manager_id}", "#{@api_key}", ''
            
            if Rails.env.staging?
              hired_candidate_posting_manager = JSON.parse(lever_user_resource.get())
            else
              hired_candidate_posting_manager = JSON.parse(lever_user_resource.get({x_lever_client_id: ENV['LEVER_X_CLIENT_ID']}))
            end
  
            hired_candidate_posting_manager['data']['email'] rescue nil
          end

          def get_candidate_requisition(requisition_id)
            requisition_base_url = 'https://api.lever.co/v1/requisitions/'
            requisition_base_url = 'https://api.sandbox.lever.co/v1/requisitions/' if Rails.env.staging?
            lever_user_resource = RestClient::Resource.new "#{requisition_base_url}#{requisition_id}", "#{@api_key}", ''
            begin
              if Rails.env.staging?
                hired_candidate_requisition = JSON.parse(lever_user_resource.get())
              else
                hired_candidate_requisition = JSON.parse(lever_user_resource.get({x_lever_client_id: ENV['LEVER_X_CLIENT_ID']}))
              end

              return hired_candidate_requisition['data']
            rescue Exception => error
              create_webhook_logging(current_company, 'Lever', 'Candidate Requisition', {requisition_id: requisition_id}, 'failed', 'LeverController/get_candidate_requisition', error.message)
            end

            return nil
          end

          def get_candidate_offer_data(opportunity_id)
            lever_offer_resource = RestClient::Resource.new "#{@opportunities_base_url}#{opportunity_id}/offers", "#{@api_key}", ''
            if Rails.env.staging?
              offers = JSON.parse(lever_offer_resource.get())
            else
              offers = JSON.parse(lever_offer_resource.get({x_lever_client_id: ENV['LEVER_X_CLIENT_ID']}))
            end

            offers['data'].last rescue nil
          end

          def get_referral_data(opportunity_id)
            lever_referral_resource = RestClient::Resource.new "#{@opportunities_base_url}#{opportunity_id}/referrals", "#{@api_key}", ''
            if Rails.env.staging?
              referral = JSON.parse(lever_referral_resource.get())
            else
              referral = JSON.parse(lever_referral_resource.get({x_lever_client_id: ENV['LEVER_X_CLIENT_ID']}))
            end

            referral['data'][0]['fields'][0] rescue {}
          end
        end
      end
    end
  end
end