class UpdateSaplingCustomGroupsFromNamelyJob < ApplicationJob
  queue_as :update_departments_and_locations

  def perform(company=nil)
    return unless company.present?
    @namely = get_namely_credentials(company)

    if @namely.present?
      begin
        puts '------Pulling Group Fields from Namely-------'

        update_department_and_team(company)

        puts '------Group Fields Pull Completed------------'
      rescue Exception => e
        puts "Namely fetching department and team #{e.inspect}"
      end
    end
  end

  private

  def update_department_and_team(company)
    if @namely.permanent_access_token.present? && @namely.company_url.present?
      groups = HTTParty.get("https://#{@namely.company_url}.namely.com/api/v1/groups",
        headers: { accept: "application/json", authorization: "Bearer #{@namely.permanent_access_token}" }
      )

      data = JSON.parse(groups.body)

      if !data.empty?
        group_types = data['linked']['group_types'] rescue []

        data['groups'].each do |group|
          field = company.custom_fields.find_by(mapping_key: group['type'])
          group_type = group_types.select { |group_type| group_type['title'].parameterize.underscore.eql?(group['type'].to_s.parameterize.underscore) }[0]['field_name'] rescue ''

          if field
            option = CustomFieldOption.find_by("(option ILIKE ? OR namely_group_id = ?) AND custom_field_id = ?", group['title'], group['id'], field.id)
            if option.present?
              option.update(option: group['title'], namely_group_type: group_type, namely_group_id: group['id'])
            else
              CustomFieldOption.create(option: group['title'], namely_group_type: group_type, namely_group_id: group['id'], custom_field_id: field.id)
            end

          elsif group['type'].parameterize.underscore != company.department_mapping_key.parameterize.underscore && group['type'].parameterize.underscore != company.location_mapping_key.to_s.parameterize.underscore
            section = company.custom_sections.find_by(section: :private_info)
            field = company.custom_fields.create(name: group['type'], section: :private_info, field_type: 4, mapping_key: group['type'], integration_group: CustomField.integration_groups[:namely], locks: {all_locks:true, options_lock:true}, custom_section_id: section.id)
            field.custom_field_options.create(option: group['title'], namely_group_type: group_type, namely_group_id: group['id'])
          end
        end
      end
    end
  end

  def get_namely_credentials(company)
    ::HrisIntegrationsService::Namely::Helper.new.fetch_integration(company)
  end
end
