module SmartAssignmentFilters
  extend ActiveSupport::Concern

  def sa_filters
    query = '';counter = 0;
    group_types = {}
    group_types["location_id"] = params[:location_id] if params[:location_id] && params[:location_id]&.compact&.present? 
    group_types["team_id"] = params[:team_id] if params[:team_id] && params[:team_id]&.compact&.present?
    group_types["employee_type"] = params[:employment_status_option] || params[:employee_type] if (params[:employment_status_option] && params[:employment_status_option]&.compact&.present?) || (params[:employee_type] && params[:employee_type]&.compact&.present?)
    
    if params["custom_groups"]
      params["custom_groups"] = JSON.parse params["custom_groups"] unless params['tab'] == 'email'
      params["custom_groups"].each do |key, value|
        group_types[key] = value if value.present?
      end
    end

    group_types.each do |key,value|
      if key && value
        query = query + build_query("'"+key+"'", value)
        counter += 1
        query = query + " AND " if counter < group_types.count && query.present?
      end
    end

    query
  end

  private

  def build_query meta_key, meta_value
    query = ''
    if meta_value
      meta_value.each_with_index do |employee, index|
        query = query + "meta -> #{meta_key} @> '" + meta_value[index].to_s + "'"
        query = query + " OR " if meta_value.length > 1  && index < meta_value.length - 1
      end
      query = query + " OR " + "meta -> #{meta_key} @> '" + ['all'].to_s + "'" + " OR meta -> #{meta_key} @> 'null'" if (params[:smart] || params[:invitation] || params[:offboarding] || params[:include_all])
      query = "(" + query + ")"
    end
    query
  end
end
