class CustomTable < ApplicationRecord
  acts_as_paranoid
  include CustomTableManagement, UserRoleManagement

  belongs_to :company
  has_many :custom_fields, dependent: :destroy
  has_many :custom_table_user_snapshots, dependent: :destroy
  has_many :approval_chains, as: :approvable, dependent: :destroy
  has_many :profile_template_custom_table_connections, dependent: :destroy

  accepts_nested_attributes_for :approval_chains, allow_destroy: true
  accepts_nested_attributes_for :custom_fields
  
  validates :name, :table_type, presence: true
  validates_uniqueness_of :name, scope: :company_id
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)
  validates_with ApprovalExpiryTimeValidator, if: Proc.new {|custom_table| custom_table.is_approval_required.present?}
  validates_with ApprovalChainValidator, if: Proc.new {|custom_table| custom_table.is_approval_required.present?}

  enum table_type: { timeline: 0, standard: 1 }
  enum custom_table_property: { general: 0, compensation: 1, role_information: 2, employment_status: 3 }
  enum approval_type: { manager: 0, person: 1, permission: 2 }

  after_create { manage_default_timeline_table_column(self, true) if table_type.present? && table_type == 'timeline' }
  after_create { add_custom_table_permissions_to_user_role(self.company, self.id) }
  after_update :manage_approval_type_requested_snapshots, if: Proc.new { |custom_table| custom_table.is_approval_required_before_last_save.present? && custom_table.is_approval_required.blank?}
  after_update :manage_non_approval_type_snapshots, if: Proc.new { |custom_table| custom_table.is_approval_required_before_last_save.blank? && custom_table.is_approval_required.present?}
  before_destroy { remove_custom_table_permissions_from_user_role(self.company, self.id) }
  after_create :flush_cache
  before_destroy :flush_cache

  scope :role_information, -> (company_id){ where(company_id: company_id, custom_table_property: CustomTable.custom_table_properties[:role_information]).take }
  scope :employment_status, -> (company_id){ where(company_id: company_id, custom_table_property: CustomTable.custom_table_properties[:employment_status]).take }
  scope :compensation, -> (company_id){ where(company_id: company_id, custom_table_property: CustomTable.custom_table_properties[:compensation]).take }
  scope :default, ->{ where.not(custom_table_property: CustomTable.custom_table_properties[:general]) }
  scope :having_property, -> (property) { where(custom_table_property: property) }

  def flush_cache
    Rails.cache.delete([self.company_id, 'custom_tables_count'])
    true
  end
  
  def manage_approval_type_requested_snapshots
    self.custom_table_user_snapshots.where(request_state: CustomTableUserSnapshot.request_states[:requested]).destroy_all
  end

  def manage_non_approval_type_snapshots
    self.custom_table_user_snapshots.where(request_state: nil).update_all(request_state: CustomTableUserSnapshot.request_states[:approved])
  end

  def add_custom_table_to_profile_template(current_company, profile_template_ids)
    profile_template_ids.each do |tempalte_id|
      template = current_company.profile_templates.find_by(id: tempalte_id)
      if template.present?
        template.profile_template_custom_table_connections.create(custom_table_id: self.id, position: ProfileTemplateCustomTableConnection.get_position(tempalte_id))
        self.custom_fields.each_with_index do |field, index|
          template.profile_template_custom_field_connections.create(custom_field_id: field.id, position: index)
        end
      end  
    end
  end

  def get_field_ids_associated
    ids = []
    ids.push(self.custom_fields.pluck(:id))
    self.company.prefrences['default_fields'].map { |field| ids.push(field['id']) if field['custom_table_property'] == self.custom_table_property }
    ids&.flatten!
  end
end
