
class ReportService

  def initialize(params = nil, user = nil)
    @params = params if params
    if params
      if params["report_id"] == "default" && user && user.company.present?
        @report = Report.default_report(user.company, params)
      elsif params["report_id"] == "turnover" && user && user.company.present?
        @report = Report.turnover_report(user.company, params)
      else
        @report = Report.find_by(id: params[:report_id])
      end
    end
    @user = user if user
  end

  def perform
    "#{@report.report_type.camelize}ReportJob".constantize.new.perform(@user, @report)
  end

  def get_sorting_params(report)
    csv_params = {}

    if report && report.meta && report.meta["sort_by"]
      if report.meta["sort_by"] == "first_name_asc"
        csv_params = {order_column: "first_name", order_in: "asc"}

      elsif report.meta["sort_by"] == "first_name_desc"
        csv_params = {order_column: "first_name", order_in: "desc"}

      elsif report.meta["sort_by"] == "last_name_asc"
        csv_params = {order_column: "last_name", order_in: "asc"}

      elsif report.meta["sort_by"] == "last_name_desc"
        csv_params = {order_column: "last_name", order_in: "desc"}

      elsif report.meta["sort_by"] == "start_date_desc"
        csv_params = {order_column: "start_date", order_in: "desc"}

      elsif report.meta["sort_by"] == "termination_date_desc"
        csv_params = {order_column: "termination_date", order_in: "desc"}

      elsif report.meta["sort_by"] == "start_date_asc"
        csv_params = {order_column: "start_date", order_in: "asc"}

      elsif report.meta["sort_by"] == "due_date_asc"
        csv_params = {order_column: "due_date", order_in: "asc"}

      elsif report.meta["sort_by"] == "due_date_desc"
        csv_params = {order_column: "due_date", order_in: "desc"}

      elsif report.meta["sort_by"] == "doc_name_asc"
        csv_params = {order_column: "doc_name", order_in: "asc"}

      elsif report.meta["sort_by"] == "doc_name_desc"
        csv_params = {order_column: "doc_name", order_in: "desc"}
      end

    end
    csv_params
  end

  def get_filter_params(report, user)
    csv_params = {}
    custom_groups = []

    custom_groups = CustomFieldsCollection.new(company_id: report.company.id, integration_group: true).results

    if report && report.meta
      if report.meta["filter_by"] && report.meta["filter_by"] == "active_only" && !report.meta["inactive_users"]
        csv_params[:registered] = true
      elsif report.meta["filter_by"] && report.meta["filter_by"] == "inactive_only"
        csv_params[:state] = "inactive"
      elsif report.meta["filter_by"] && report.meta["filter_by"] == "departed_only"
        csv_params[:departed] = true
      elsif report.meta["filter_by"] && report.meta["filter_by"] == "incomplete_only"
        csv_params[:incomplete] = true
      elsif report.meta["filter_by"] && report.meta["filter_by"] == "onboarding_only"
        csv_params[:onboarding_employees] = true
      elsif report.meta["filter_by"] && report.meta["filter_by"] == "offboarding_only"
        csv_params[:offboarding_employees] = true
      elsif report.meta["filter_by"] && report.meta["filter_by"] == "all_employees"
        csv_params[:all_employees] = true
      elsif report.meta["filter_by"] && report.meta["filter_by"] == "in_progress_docs"
        csv_params[:status] = "in_progress_docs"
      elsif report.meta["filter_by"] && report.meta["filter_by"] == "completed_docs"
        csv_params[:status] = "completed_docs"
      elsif report.meta["filter_by"] && report.meta["filter_by"] == "selected_date"
        csv_params[:selected_end_date] = true
        csv_params[:default_report_type] = 'default_user_report' if report.name === 'default' && report.report_type === 'user'
      elsif report.meta["filter_by"] && report.meta["filter_by"] == "turnover_departed_users"
        csv_params[:turnover_departed_users] = true
      end

      if report.report_type == "workflow"
        if report.meta["workflow_tasks_filters"] && (report.meta["workflow_tasks_filters"].include? 1)
          csv_params[:overdue] = true
        end
        if report.meta["workflow_tasks_filters"] && (report.meta["workflow_tasks_filters"].include? 2) && (report.meta["workflow_tasks_filters"].exclude? 3)
          csv_params[:state] = "in_progress"
        elsif report.meta["workflow_tasks_filters"] && (report.meta["workflow_tasks_filters"].include? 3) && (report.meta["workflow_tasks_filters"].exclude? 2)
          csv_params[:state] = "completed"
        end
      end

      if report.report_type == "survey"
        if report.meta["workflow_tasks_filters"] && ['in_progress', 'completed'].include?(report.meta["workflow_tasks_filters"])
          csv_params[:state] = report.meta["workflow_tasks_filters"]
        end
      end

      csv_params[:only_managers] = report.meta["only_managers"]
      if report.meta["mcq_filters"] && report.meta["mcq_filters"].first.present?
        csv_params[:mcq_filters] = report.meta["mcq_filters"]
      end

      if report.report_type == 'user' && report.meta['termination_type_filter'].present?
        csv_params[:termination_type_filter] = report.meta['termination_type_filter']
      end

      if user && user.admin?
        team_permission_level = user.user_role.team_permission_level.reject(&:empty?).uniq
        if report.meta["team_id"]
          csv_params[:team_id] = []
          report.meta["team_id"].each do |team|
            csv_params[:team_id].push(team) if team_permission_level.include?(team.try(:to_s)) || team_permission_level.include?('all')
          end
        elsif !team_permission_level.include?('all')
          csv_params[:team_id] = team_permission_level
        end

        location_permission_level = user.user_role.location_permission_level.reject(&:empty?).uniq
        if report.meta["location_id"]
          csv_params[:location_id] = []
          report.meta["location_id"].each do |location|
            csv_params[:location_id].push(location) if  location_permission_level.include?(location.try(:to_s)) || location_permission_level.include?('all')
          end
        elsif !location_permission_level.include?('all')
          csv_params[:location_id] = location_permission_level
        end

        status_permission_level = user.user_role.status_permission_level.reject(&:empty?).uniq
        if report.meta["employee_type"] && report.meta["employee_type"] != 'all_employee_status'
          csv_params[:employee_type] = []

          if report.meta["employee_type"].class == Array
            report.meta["employee_type"].each do |employee_type|
                csv_params[:employee_type].push(employee_type) if status_permission_level.include?(employee_type.try(:to_s)) || status_permission_level.include?('all')
            end
          elsif report.meta["employee_type"].class == String
            csv_params[:employee_type].push(report.meta["employee_type"]) if status_permission_level.include?(report.meta["employee_type"].try(:to_s)) || status_permission_level.include?('all')
          end
        elsif !status_permission_level.include?('all')
          csv_params[:employee_type] = status_permission_level
        end
      else
        csv_params[:team_id] = report.meta["team_id"] if report.meta["team_id"].present?
        csv_params[:location_id] = report.meta["location_id"] if report.meta["location_id"].present?
        csv_params[:employee_type] = report.meta["employee_type"] if report.meta["employee_type"] && report.meta["employee_type"] != 'all_employee_status'
      end

      custom_group_ids = []
      custom_groups.each do |group|
        group_hash = {}
        if report.meta[group.id.to_s] && !report.meta[group.id.to_s].index('all')
          group_hash[:custom_field_id] =  group.id
          group_hash[:custom_field_option_id] = report.meta[group.id.to_s]
          custom_group_ids.push group_hash
        end
      end
      csv_params[:multiple_custom_groups] = custom_group_ids if custom_group_ids.length > 0

    end
    csv_params
  end

  def get_start_end_date(report)
    date_range_object = {}
    if report && report.meta
      date_range_object[:start_date] = get_updated_date_time_range(report)[:start_date]
      date_range_object[:end_date] = get_updated_date_time_range(report)[:end_date]
    else
      date_range_object[:start_date] = nil
      date_range_object[:end_date] = nil
    end
    date_range_object
  end

  def update_start_end_date(report, required_dates)
    return if required_dates.blank? || report.blank?
    
    is_report_change = false
    date_range_type = report.meta['date_range_type']
    if date_range_type.present? && date_range_type == 4
      required_dates[:start_date] = required_dates[:start_date]&.strftime('%m/%d/%Y')
      required_dates[:end_date] = required_dates[:end_date]&.strftime('%m/%d/%Y') 
    end

    if required_dates[:start_date].present? && required_dates[:start_date] != report.meta['start_date']
      report.meta['start_date'] = required_dates[:start_date]
      is_report_change = true
    end

    if required_dates[:end_date].present? && required_dates[:end_date] != report.meta['end_date']
      report.meta['end_date'] = required_dates[:end_date]
      is_report_change = true
    end
    
    report.save! if is_report_change
  end

  private

  def get_updated_date_time_range report
    resultant_object = {}
    date_range_type = report.meta['date_range_type'] rescue nil
    if date_range_type.present?
      if date_range_type == 0
        resultant_object[:start_date] = (Date.today - 31).strftime("%m/%d/%Y") rescue nil
        resultant_object[:end_date] = (Date.today - 1).strftime("%m/%d/%Y") rescue nil
      elsif date_range_type == 1
        resultant_object[:start_date] = (Date.today - 8).strftime("%m/%d/%Y") rescue nil
        resultant_object[:end_date] = (Date.today - 1).strftime("%m/%d/%Y") rescue nil
      elsif date_range_type == 2
        resultant_object[:start_date] = (Date.today - 1.month).beginning_of_month.strftime("%m/%d/%Y") rescue nil
        resultant_object[:end_date] = (Date.today - 1.month).end_of_month.strftime("%m/%d/%Y") rescue nil
      elsif date_range_type == 3
        resultant_object[:start_date] = (Date.today - 1.week).beginning_of_week.strftime("%m/%d/%Y") rescue nil
        resultant_object[:end_date] = (Date.today - 1.week).end_of_week.strftime("%m/%d/%Y") rescue nil
      elsif date_range_type == 4
        resultant_object[:start_date] = Date.strptime(report.meta['start_date'],'%m/%d/%Y') rescue nil
        resultant_object[:end_date] = Date.strptime(report.meta['end_date'],'%m/%d/%Y') rescue nil
      end
    else
      resultant_object[:start_date] = nil
      resultant_object[:end_date] = nil
    end
    resultant_object
  end

end
