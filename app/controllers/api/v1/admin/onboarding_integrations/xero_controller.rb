module Api
  module V1
    module Admin
      module OnboardingIntegrations
        class XeroController < ApiController
          before_action :require_company!, except: [:authorize]
          before_action :verify_state, only: [:authorize]
          before_action :initialize_hr_service, except: [:new, :authorize]
          before_action :initialize_service
          
          rescue_from CanCan::AccessDenied do |exception|    
            render body: Sapling::Application::EMPTY_BODY, status: 401
          end

          def new
            render json: {"url": @application.authorize_app_url}
          end

          def authorize
            if params['error'] && params['error'] == 'access_denied'
              validation_params = 'xero-failure'
              response = 'failure'
            else
              if @application.save_access_token == true
                validation_params = 'xero'
                response = 'success'
              else
                validation_params = 'xero-failure'
                response = 'failure'
              end
            end

            if Rails.env.development?
              redirect_to "http://#{current_company.app_domain}/#/admin/settings/integrations?map=xero&response=#{response}"
            else
              redirect_to "http://#{current_company.app_domain}/#/admin/settings/integrations?map=xero&response=#{response}"
            end
          end

          def get_organisations
            organisation = @hr_service.fetch_organisations
            render json: organisation
          end

          def get_payroll_calendars
            payroll_calendar = @hr_service.fetch_payroll_calendars
            render json: payroll_calendar
          end

          def get_employee_group_names
            employee_group_names = @hr_service.fetch_employee_groups
            render json: employee_group_names
          end

          def get_pay_templates
            pay_templates = @hr_service.fetch_pay_templates
            render json: pay_templates
          end

        private

          def initialize_service
            @application = HrisIntegrationsService::Xero::InitializeApplication.new(@current_company, params, @instance_id, @current_user_id)
          end

          def initialize_hr_service
            @hr_service = HrisIntegrationsService::Xero::HumanResource.new(current_company, @instance_id, @current_user_id)
          end

          def verify_state
            @current_company, @instance_id, @current_user_id = HrisIntegrationsService::Xero::Helper.new.verify_state_and_fetch_company(params)
          end
        end
      end
    end
  end
end
