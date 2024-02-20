class UpdateSaplingDepartmentsAndLocationsFromNamelyJob < ApplicationJob
  queue_as :update_departments_and_locations

  def perform(integration=nil, company=nil)
    @namely = get_namely_credentials(company)

    if @namely.present?
      update_department_and_location(company)
    end
  end

  private

  def update_department_and_location(company)
    begin
      if @namely.permanent_access_token.present? && @namely.company_url.present?
        groups = HTTParty.get("https://#{@namely.company_url}.namely.com/api/v1/groups",
          headers: { accept: "application/json", authorization: "Bearer #{@namely.permanent_access_token}" }
        )
        data = JSON.parse(groups.body)

        if !data.empty?
            group_types = data['linked']['group_types'] rescue []

            if company.department_mapping_key.present?
              departments = data['groups'].select { |department_and_location| department_and_location['type'].parameterize.underscore.eql?(company.department_mapping_key.to_s.parameterize.underscore) }
              if departments.present?
                group_type = fetch_group_type(group_types, company.department_mapping_key) rescue nil
                Team.update_departments_from_namely(departments, company, group_type)
              end
            end

            if company.location_mapping_key.present?
              locations = data['groups'].select { |department_and_location| department_and_location['type'].parameterize.underscore.eql?(company.location_mapping_key.to_s.parameterize.underscore) }
              if locations.present?
                group_type = fetch_group_type(group_types, company.location_mapping_key) rescue nil
                Location.update_locations_from_namely(locations, company, group_type)
              end
            end
        end
      end
    rescue Exception => e
      LoggingService::IntegrationLogging.new.create(@namely.company, 'Namely', 'Update Sapling Location Department', nil, {error: e.message}, 500)
    end
  end

  def fetch_group_type(group_types, mapping_key)
    group_types.select { |group_type| group_type['title'].parameterize.underscore.eql?(mapping_key.to_s.parameterize.underscore) }[0]['field_name'] rescue nil
  end

  def get_namely_credentials(company)
    ::HrisIntegrationsService::Namely::Helper.new.fetch_integration(company)
  end
end
