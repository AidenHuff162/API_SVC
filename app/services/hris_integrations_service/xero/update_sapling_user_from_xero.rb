module HrisIntegrationsService
  module Xero
    class UpdateSaplingUserFromXero
      attr_reader :company, :integration, :filters_query

      delegate :create_loggings, to: :helper_service
      delegate :fetch_users, to: :hris_service

      def initialize(company, integration)
        @company = company
        @filters_query = initialize_filters_query(integration&.filters)
        @should_fetch_ids = fetch_sapling_users.present?
      end

      def update
        fetch_updates if @should_fetch_ids.present?
      rescue Exception => e
        create_loggings(company, 'Xero', '500', 'Update Xero Profile in sapling - ERROR', { message: e.message })
      end

      def fetch_sapling_users
        if filters_query.include?('custom_field_options.option')
          company.users.joins(custom_field_values: [custom_field_option: :custom_field]).where(filters_query)
                 .where('current_stage != ? AND xero_id IS NULL AND super_user = ?',
                        User.current_stages[:incomplete], false)
        else
          company.users.where(filters_query)
                 .where('current_stage != ? AND xero_id IS NULL AND super_user = ?', User.current_stages[:incomplete], false)
        end
      end

      private

      def fetch_updates
        startIndex = 1
        fetch_more = true
        miss_matched_emails = []
        matched_emails = []

        while fetch_more
          response = fetch_users(startIndex)

          break if response['Employees'].blank?

          fetch_more = false if response['Status'] != 'OK'
          startIndex += 1

          response['Employees'].try(:each) do |resource|
            xero_id = begin
              resource['EmployeeID']
            rescue StandardError
              nil
            end
            next if xero_id.blank? || (xero_id.present? && @company.users.exists?(xero_id: xero_id))

            map_xero_ids(resource, miss_matched_emails, matched_emails)
          end
        end

        if miss_matched_emails.present?
          create_loggings(company, 'Xero', 200, 'Fetch Xero IDs - Mismatched emails', miss_matched_emails,
                          'fetch_users')
        end
        create_loggings(company, 'Xero', 200, 'Fetch Xero IDs - Matched emails', matched_emails, 'fetch_users') if matched_emails.present?
      end

      def map_xero_ids(resource, miss_matched_emails, matched_emails)
        emails = resource['Email']

        if emails.present?
          users = fetch_sapling_users.where('(personal_email IN (?) OR email IN (?))', emails, emails)
          if users.blank?
            miss_matched_emails.push({ sapling: 'No match', Xero: { id: resource['EmployeeID'], emails: emails } })
          elsif users.count == 1
            matched_emails.push({ sapling: { user: users.pluck(:id, :email, :personal_email) },
                                  Xero: { id: resource['EmployeeID'], emails: emails } })
            users.update_all(xero_id: resource['EmployeeID'])
          else
            miss_matched_emails.push({ sapling: { user: users.pluck(:id, :email, :personal_email) },
                                       Xero: { id: resource['EmployeeID'], emails: emails } })
          end
        end
      rescue Exception => e
        create_loggings(comapny, 'Xero', 500, 'Map Xero ID code issue', { message: e.message })
      end

      def helper_service
        ::HrisIntegrationsService::Xero::Helper.new
      end

      def hris_service
        HrisIntegrationsService::Xero::HumanResource.new company
      end

      def initialize_filters_query(filters)
        return '' if filters.blank?

        build_query(filters)
      end

      def build_query(filters)
        query = ''
        query += "location_id IN (#{filters['location_id'].map(&:inspect).join(',')})" if filters['location_id'] != ['all']
        query = append_and_operation(query, filters['team_id'])
        query += "team_id IN (#{filters['team_id'].map(&:inspect).join(',')})" if filters['team_id'] != ['all']
        query = append_and_operation(query, filters['employee_type'])
        query + employee_type_query(filters['employee_type'])
      end

      def append_and_operation(query, filters)
        filters != ['all'] && query.present? ? "#{query} ' AND '" : query
      end

      def employee_type_query(filters)
        return '' if filters == ['all']

        employee_type = filters.map(&:to_s).join("', '")
        "custom_fields.company_id = #{company.id} AND custom_fields.field_type = 13 AND custom_field_options.option IN ('#{employee_type}')"
      end
    end
  end
end
