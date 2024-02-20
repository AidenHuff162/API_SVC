namespace :manage_lever_field_mapping do

    desc 'Create Lever Fields '
    task lever_fields: :environment do

        puts "Starting Changing Field Mappings"  

		integrations = IntegrationInstance.where(api_identifier: "lever")

		integrations.each do |integration|
		    integration_field_mappings = integration.integration_field_mappings
			department_fields = integration_field_mappings.where(integration_field_key: "team_id")
			department_fields.each do |d|
				if d.integration_selected_option && d.integration_selected_option["name"] == "Department (Offer Form)"
					d.integration_selected_option["name"] = "Team (Offer Form)"
					d.integration_selected_option["id"] = "team_offer_data"
					d.integration_selected_option["section"] = "offer_data"
					d.save!
				elsif d.integration_selected_option && d.integration_selected_option["name"] == "Department (Job Posting)"
					d.integration_selected_option["name"] = "Team (Job Posting)"
					d.integration_selected_option["id"] = "team_candidate_posting_data"
					d.integration_selected_option["section"] = "candidate_posting_data"
					d.save!
			    end
			end
		end

        puts "Completed Changing Field Mappings"
	end

	desc 'Update dropdown options for department'
	task update_department_options: :environment do

		puts "Starting Updating Department options"
		integration_inventory = IntegrationInventory.find_by_api_identifier('lever')
        map = {key: 'team_id', name: 'Department', mapping_options: [{id: 'location_candidate_data', name: 'Location (Candidate)', section: 'candidate_data'}, {id: 'location_hired_candidate_form_fields', name: 'Location (Form Fields)', section: 'hired_candidate_form_fields'}, {id: 'location_offer_data', name: 'Location (Offer Form)', section: 'offer_data'}, {id: 'location_candidate_posting_data', name: 'Location (Job Posting)', section: 'candidate_posting_data'}, {id: 'location_hired_candidate_requisition_data', name: 'Location (Requisition)', section: 'hired_candidate_requisition_data'}, {id: 'team_offer_data', name: 'Team (Offer Form)', section: 'offer_data'}, {id: 'team_candidate_posting_data', name: 'Team (Job Posting)', section: 'candidate_posting_data'}, {id: 'department_offer_data', name: 'Department (Offer Form)', section: 'offer_data'}, {id: 'department_candidate_posting_data', name: 'Department (Job Posting)', section: 'candidate_posting_data'}, {id: 'department_hired_candidate_requisition_data', name: 'Team (Requisition)', section: 'hired_candidate_requisition_data'}]}
        integration_inventory.inventory_field_mappings.where("trim(inventory_field_key) ILIKE ?", map[:key]).update({inventory_field_key: map[:key], inventory_field_name: map[:name], integration_mapping_options: map[:mapping_options]})
		puts "Completed Updating Department options"
	end

	desc "Execute all tasks"
	task all: [:update_department_options, :lever_fields] 
end