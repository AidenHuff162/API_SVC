module SsoIntegrationsService
  module Shibboleth
    module UCSF
      class FetchUserByResponse
        attr_reader :response, :current_company

        def initialize response, current_company
          res_obj = response.attributes.attributes.values
          @email = res_obj[1][0]
          @emp_number = res_obj[0][0]
          @company = current_company
        end

        def perform
          get_user_by_employee_number
        end

        private

        def get_user_by_employee_number
          User.get_from_employee_number_and_email(@emp_number, @email, @company)
        end

      end
    end
  end
end
