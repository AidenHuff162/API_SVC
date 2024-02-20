class CsvUploadWorkdayFieldsJob < ApplicationJob
  queue_as :default

  attr_reader :company, :uploaded_field_ids, :csv

  def initialize(company_id, csv)
    @company = Company.find_by_id(company_id)
    @csv = csv
    @uploaded_field_ids = []
  end

  def perform
    return if company.blank?

    upload_fields
    sort_in_ascending_order
  end

  private

  def upload_fields
    CSV.parse(csv, headers: true) do |row|
      entry = row.to_hash
      field_name, instance, workday_id = ['Sapling Field', 'Instance', 'Workday ID'].map { |val| entry[val]&.strip }
      custom_field = company.custom_fields.where('trim(name) ILIKE ?', field_name).take
      next unless custom_field.present? && custom_field.mcq?

      uploaded_field_ids << custom_field.id
      custom_field_option = custom_field.custom_field_options.where('trim(option) ILIKE ? OR workday_wid = ?', instance, workday_id).take
      if custom_field_option.present?
        custom_field_option.update!(option: instance, workday_wid: workday_id)
      else
        custom_field.custom_field_options.create!(option: instance, workday_wid: workday_id)
      end
    end
  end

  def sort_in_ascending_order
    uploaded_field_ids.uniq.each do |field_id|
      i, field_options = 0, CustomFieldOption.where('custom_field_id = ? AND option != ?', field_id, 'Not Applicable')
      field_options.order(option: :asc).each do |option|
        option.update_column(:position, (i += 1))
      end
    end
    CustomFieldOption.where(option: 'Not Applicable', custom_field_id: uploaded_field_ids).each do |option|
      option.update_column(:position, 0)
    end
  end

end
