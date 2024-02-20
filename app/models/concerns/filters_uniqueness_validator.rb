class FiltersUniquenessValidator < ActiveModel::Validator
  def validate record
    invalid_filters(record) 
  end

  def invalid_filters record
    filters = IntegrationInstance.fetch_exisiting_filters(record.id, record.company_id, record.integration_inventory.category).pluck(:filters)
    filters.each do |filter|
      record.errors.add(:filters, I18n.t('errors.filter_duplication').to_s) if check_location_duplication(filter, record) && check_department_duplication(filter, record) && check_employee_type_duplication(filter, record)
    end
  end


  def check_location_duplication(filter, record)
    location_filter_set = filter['location_id'].reject { |c| c.to_s.empty? }.to_set
    location_record_set = record.filters['location_id'].reject { |c| c.to_s.empty? }.to_set
    
    !location_filter_set.empty? && !location_record_set.empty? && (location_filter_set.include?(['all'].to_set) || location_record_set.subset?(['all'].to_set) || location_filter_set.subset?(location_record_set))
  end

  def check_department_duplication(filter, record)
    department_filter_set = filter['team_id'].reject { |c| c.to_s.empty? }.to_set
    department_record_set = record.filters['team_id'].reject { |c| c.to_s.empty? }.to_set

    !department_filter_set.empty? && !department_record_set.empty? && (department_filter_set.include?(['all'].to_set) || department_record_set.subset?(['all'].to_set) || department_filter_set.subset?(department_record_set))
  end

  def check_employee_type_duplication(filter, record)
    employee_type_filter_set = filter['employee_type'].reject { |c| c.to_s.empty? }.to_set
    employee_type_record_set = record.filters['employee_type'].reject { |c| c.to_s.empty? }.to_set

    !employee_type_filter_set.empty? && !employee_type_record_set.empty? && (employee_type_filter_set.include?(['all'].to_set) || employee_type_record_set.subset?(['all'].to_set) || employee_type_filter_set.subset?(employee_type_record_set))
  end
end