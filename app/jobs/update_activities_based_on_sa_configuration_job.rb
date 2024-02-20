class UpdateActivitiesBasedOnSaConfigurationJob
  include Sidekiq::Worker
  sidekiq_options :queue => :update_smart_assignment_configuration_activities, :retry => false, :backtrace => true

  def perform(company_id)
  	return unless company_id.present?
      company = Company.find_by_id(company_id)
      sa_configuration = company&.smart_assignment_configuration
      return unless sa_configuration

      activity_filters = sa_configuration.meta["activity_filters"]
      return unless activity_filters
      employee_status_field = company.custom_fields.where(field_type: 13).take
      activity_filter_keys = createKeyFromId(activity_filters, employee_status_field)

      updateActivity(company.workstreams, false, activity_filter_keys) if company.workstreams.count > 0
      updateActivity(company.profile_templates, false, activity_filter_keys) if company.profile_templates.count > 0
      updateActivity(company.email_templates, false, activity_filter_keys) if company.email_templates.count > 0
      updateActivity(company.paperwork_packets, true, activity_filter_keys) if company.paperwork_packets.count > 0
      updateActivity(company.document_upload_requests, true, activity_filter_keys) if company.document_upload_requests.count > 0
      updateActivity(company.documents, true, activity_filter_keys) if company.documents.count > 0     
  end

  def updateActivity(activity_array, add_process_type_to_meta = false, activity_filter_keys)
    activity_array.try(:find_each) do |activity|
      process_type = activity&.meta['type'] if add_process_type_to_meta
      updated_meta = updateMetaFiltersBasedOnSaSettings(activity, activity_filter_keys)
      updated_meta['type'] = process_type if updated_meta && add_process_type_to_meta
      activity.update_column(:meta, updated_meta) if updated_meta
    end 
  end

  def updateMetaFiltersBasedOnSaSettings(object, activity_filter_keys)
    meta_keys = object.meta.map{|k,v| k}
    meta = object.meta

    missing_keys = activity_filter_keys - meta_keys 
    additional_keys = meta_keys - activity_filter_keys

    missing_keys.map { |key| addKeyToMeta(meta, key) }
    additional_keys.map{ |key| removeKeyFromMeta(meta, key) }

    meta
  end

  def addKeyToMeta(meta, key)
    meta[key] = ["all"]
  end

  def removeKeyFromMeta(meta, key)
    meta.delete(key)
  end

  def createKeyFromId(activity_filters, employee_status_field)
    keys = []
    activity_filters.each do |filter_id|
      if filter_id == 'loc'
        keys.push('location_id')
      elsif filter_id == 'dpt'
        keys.push('team_id')
      elsif filter_id == employee_status_field&.id.to_s
        keys.push("employee_type")
      else
        keys.push(filter_id)
      end
    end
    keys
  end
end