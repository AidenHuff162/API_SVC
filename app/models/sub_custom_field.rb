class SubCustomField < ApplicationRecord
  has_paper_trail
  belongs_to :custom_field
  has_many :custom_field_values, dependent: :destroy

  accepts_nested_attributes_for :custom_field_values
  # after_commit :flush_cache

  enum field_type: { short_text: 0, long_text: 1, multiple_choice: 2, confirmation: 3, mcq: 4, social_security_number: 5, date: 6, address: 7, coworker: 8, multi_select: 9, number: 10, social_insurance_number: 11}

  def self.get_sub_custom_field(company, field_name, sub_field_name, default_field = nil)
    custom_field = default_field.present? ? default_field : CustomField.get_custom_field(company, field_name)
    return if !custom_field.present?
    custom_field.sub_custom_fields.find_by('name ILIKE ?', sub_field_name)
  end

  def get_sub_custom_field_values_by_user user_id
    #Key Rails.cache.fetch(CustomField/UserId/custom_field_values)
    # Rails.cache.fetch([self.id, user_id, 'sub_custom_field_values'], expires_in: 5.days) do
      value = self.custom_field_values.find_by(user_id: user_id)
      (value.present? && value.deleted_at.nil?) ? value : nil
    # end
  end

  def flush_cache
    user_ids = self.custom_field_values.pluck(:user_id).uniq
    user_ids.each do |user_id|
      Rails.cache.delete([self.id, user_id, 'sub_custom_field_values'])
    end
    true
  end

  def self.show_sub_custom_fields(custom_field)
    if custom_field.field_type == 'address' || custom_field.field_type == 'currency'
      return true
    else
      return false
    end
  end

end
