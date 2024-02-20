class SmartAssignmentConfiguration < ApplicationRecord
	belongs_to :company
	has_paper_trail

	# meta attributes => 1) activity_filters 2) smart_assignment_filters  
	
	# activity_filters 
	# => Contains array of group type field ids selected at the step-1 of Smart Assignment Configuration Model
	# => These SA filters will be rendered dynamiclly for the activities (workflows, documents, profile templates and email templates) when SA feature flag is turned ON 
	
	# smart_assignment_filters
	# => Contains array of group type field ids selected at the step-2 of Smart Assignment Configuration Model
	# => These SA filters will be rendered dynamiclly during onboarding, offboadring and bulk onboarding flow when SA feature flag is turned ON

	after_commit :run_update_activities_job

	def run_update_activities_job
		UpdateActivitiesBasedOnSaConfigurationJob.perform_in(5.seconds, self.company_id)
	end
end
