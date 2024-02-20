class IntegrationsService::Filters < ApplicationService
  attr_reader :integration, :records, :filters, :location_ids, :team_ids, :employment_types

  def initialize(records, integration)
    @records = records
    @integration = integration
    @filters = integration.try(:filters)
  end

  def call
    return User.none unless filters.present? && records.present?

    set_lde_values
    if (records_relation = convert_array_to_relation)
      get_filter_applicable_records(records_relation)
    else
      # this means record is a single object of User, PendingHire or Hash
      records if filter_applicable?(records)
    end
  end

  private

  def set_lde_values
    @location_ids, @team_ids, @employment_types = %w[location_id team_id employee_type].map { |type| filters[type].compact }
  end

  def convert_array_to_relation
    case records
    when Array
      records.first.class.where(id: records.map(&:id)) rescue User.none
    when ActiveRecord::Relation
      records
    end
  end

  def filter_applicable?(record)
    (apply_to_location?(record) && apply_to_team?(record) && apply_to_employee_type?(record))
  end

  def apply_to_location?(record)
    (location_ids & ['all', record[:location_id]]).any?
  end

  def apply_to_team?(record)
    (team_ids & ['all', record[:team_id]]).any?
  end

  def apply_to_employee_type?(record)
    (employment_types.map(&:downcase) & ['all', get_employee_type_field_value(record)]).any?
  end

  def get_employee_type_field_value(record)
    (record.instance_of?(User) ? record.employee_type : record[:employee_type])&.downcase
  end

  def value_for_where_clause(values)
    values.exclude?('all') ? values : nil # return nil to remove it from filters, removing from filter will do the work of 'all'
  end

  def get_employment_type_params
    # if employment_types = 'all', we won't consider this check in query
    return {} unless (option = value_for_where_clause(employment_types))

    { 'custom_fields.field_type': CustomField.field_types[:employment_status], 'custom_field_options.option': option }
  end

  def filter_applicable_params(is_pending_hire: false)
    params = { location_id: value_for_where_clause(location_ids), team_id: value_for_where_clause(team_ids) }
    params[:employee_type] = value_for_where_clause(employment_types) if is_pending_hire
    params.compact
  end

  def get_filter_applicable_records(relation)
    if relation.first.is_a?(PendingHire)
      relation.where(filter_applicable_params(is_pending_hire: true))
    else
      result = relation.where(filter_applicable_params)
      if (employment_type_params = get_employment_type_params).present?
        result = result.joins(custom_field_values: %i[custom_field custom_field_option]).where(employment_type_params)
      end
      result
    end
  end

end
