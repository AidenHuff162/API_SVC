module Api
  module V1
    module Admin
      module WebhookIntegrations
        class NamelyController < WebhookController
          before_action :namely_credentials, only: [:job_title_index, :departments_and_locations_index, :job_tier_index, :create_job_tier_and_title]
          before_action :current_company

          include JsonResponder
          respond_to :json
          responders :json

          def job_tier_index
            access_token = @namely_api.permanent_access_token rescue nil
            subdomain = @namely_api.company_url rescue nil
            job_tiers = []

            if access_token.present? && subdomain.present?
              begin
                namely = Namely::Connection.new(
                  access_token: access_token,
                  subdomain: subdomain
                )
                job_tiers = namely.job_tiers.all.map(&:title)
                job_tiers = job_tiers.uniq
              rescue Exception => e
                job_tiers = []
              end
            end
            respond_with job_tiers.to_json
          end

          def job_title_index
            access_token = @namely_api.permanent_access_token rescue nil
            subdomain = @namely_api.company_url rescue nil
            job_titles = []

            if access_token.present? && subdomain.present?
              begin
                namely = Namely::Connection.new(
                  access_token: access_token,
                  subdomain: subdomain
                )
                if !params[:tier].present?
                  job_titles = namely.job_titles.all.map(&:title)
                elsif params[:tier].present?
                  parent_id = namely.job_tiers.all.select { |tier| tier.title.downcase.eql?(params[:tier].downcase) }.first.id rescue nil
                  if !parent_id.present?
                    job_titles = namely.job_titles.all.map(&:title)
                  elsif parent_id.present?
                    namely.job_titles.all.each { |job_title| job_titles.push(job_title.title) if job_title.parent_id == parent_id }
                  end
                end
                job_titles = job_titles.uniq
              rescue Exception => e
                job_titles = []
              end
            end
            respond_with job_titles.to_json
          end

          def departments_and_locations_index
            access_token = @namely_api.permanent_access_token rescue nil
            subdomain = @namely_api.company_url rescue nil
            departments_and_locations = {
              departments: [],
              locations: []
            }

            if access_token.present? && subdomain.present?
              groups = HTTParty.get("https://#{subdomain}.namely.com/api/v1/groups",
                headers: { accept: "application/json", authorization: "Bearer #{access_token}" }
                )
              data = JSON.parse(groups.body)
              group_types = data['linked']['group_types'] rescue []

              UpdateSaplingCustomGroupsFromNamelyJob.perform_later(current_company) if current_company.subdomain.eql?('cruise')

              begin
                namely_departments = []
                namely_departments = data['groups'].select { |department_and_location| department_and_location['type'].parameterize.underscore.eql?(current_company.department_mapping_key.to_s.parameterize.underscore) }
                group_type = group_types.select { |group_type| group_type['title'].parameterize.underscore.eql?(current_company.department_mapping_key.to_s.parameterize.underscore) }[0]['field_name'] rescue nil

                Team.update_departments_from_namely(namely_departments, current_company, group_type)
                departments = current_company.teams.where.not(namely_group_id: nil, namely_group_type: nil).order(:name)
              rescue Exception => e
                puts "Exception #{e.inspect}"
                departments = current_company.teams.where.not(namely_group_id: nil, namely_group_type: nil).order(:name)
              end

              begin
                namely_locations = data['groups'].select { |department_and_location| department_and_location['type'].parameterize.underscore.eql?(current_company.location_mapping_key.to_s.parameterize.underscore) }
                group_type = group_types.select { |group_type| group_type['title'].parameterize.underscore.eql?(current_company.location_mapping_key.to_s.parameterize.underscore) }[0]['field_name'] rescue nil

                Location.update_locations_from_namely(namely_locations, current_company, group_type)
                locations = current_company.locations.where.not(namely_group_id: nil, namely_group_type: nil).order(:name)
              rescue Exception => e
                puts "Exception #{e.inspect}"
                locations = current_company.locations.where.not(namely_group_id: nil, namely_group_type: nil).order(:name)
              end

              departments_and_locations[:departments] = departments
              departments_and_locations[:locations] = locations
            end

            respond_with departments_and_locations.to_json
          end

          def create_job_tier_and_title
            access_token = @namely_api.permanent_access_token rescue nil
            subdomain = @namely_api.company_url rescue nil
            if access_token.present? && subdomain.present?
              CreateJobTierAndTitleInNamelyJob.perform_later(@namely_api, params[:title], params[:tier], current_company.id)
            end
            respond_with true.to_json
          end

        end
      end
    end
  end
end
