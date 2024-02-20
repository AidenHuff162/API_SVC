module CompanySerializer
  class HeapProperties < ActiveModel::Serializer
  	attribute :surveys_enabled,    key: :account_surveys_addon
  	attribute :enabled_time_off,   key: :account_pto_addon
  	attribute :enabled_calendar,   key: :account_calendar_addon
  	attribute :enabled_org_chart,  key: :account_org_chart_addon
  	attribute :enable_custom_table_approval_engine,  key: :account_track_approve_addon

  	attributes :account_id, :account_name, :account_subdomain, :account_integration_names, :account_type, 
  						 :account_total_people, :account_state, :account_locations_count, :account_active_people

  	def account_id
  		object.id
  	end

  	def account_name
  		object.name
  	end

  	def account_subdomain
  		object.subdomain
  	end

  	def account_integration_names
  		object.active_integration_names.join(', ') || 'null'
  	end

  	def account_total_people
  		object.users.not_incomplete.count
  	end

  	def account_locations_count
  		object.locations.count
  	end

  	def account_active_people 
  		object.users.not_inactive_incomplete.count
  	end
  end
 end