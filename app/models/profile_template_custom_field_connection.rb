class ProfileTemplateCustomFieldConnection < ApplicationRecord
  acts_as_paranoid
  validates :profile_template, :position, presence: true
  validate :ensure_custom_or_default_field
  validate :field_uniqueness, on: :create
  belongs_to :custom_field
  belongs_to :profile_template

  default_scope { order(position: :asc) }

  private

  def ensure_custom_or_default_field
    add_error = false
    if (self.custom_field_id.nil? && self.default_field_id.nil?) || (self.custom_field_id && self.default_field_id)
      add_error = true
    else
      if self.custom_field_id
        add_error = true unless self.profile_template.company.custom_fields.find_by(id: self.custom_field_id)
      elsif self.default_field_id
        add_error = true unless self.profile_template.company.prefrences["default_fields"].select { |df| df["id"] == self.default_field_id }.length == 1
      end
    end
    errors.add(:base, "Must belong to a custom field or default field") if add_error
  end

  def field_uniqueness
    not_unique = self.custom_field_id && self.profile_template.profile_template_custom_field_connections.find_by(custom_field_id: self.custom_field_id).present?
    not_unique = not_unique || (self.default_field_id && self.profile_template.profile_template_custom_field_connections.find_by(default_field_id: self.default_field_id).present?)
    errors.add(:base, "Field has already been added to this template.") if not_unique
  end

end
