class IntegrationInventory < ApplicationRecord
  has_many :integration_configurations, dependent: :destroy
  has_many :integration_instances, -> { with_deleted }, dependent: :delete_all
  has_many :visible_integration_configurations, -> { where(is_visible: true).order(:position) }, class_name: 'IntegrationConfiguration', foreign_key: :integration_inventory_id
  has_many :invisible_integration_configurations, -> { where(is_visible: false) }, class_name: 'IntegrationConfiguration', foreign_key: :integration_inventory_id
  has_one :display_logo, as: :entity, dependent: :destroy, class_name: 'UploadedFile::DisplayLogoImage'
  has_one :dialog_display_logo, as: :entity, dependent: :destroy, class_name: 'UploadedFile::DialogDisplayLogoImage'
  has_many :inventory_field_mappings, dependent: :destroy
  
  validates :api_identifier, uniqueness: true

  scope :active_inventories, -> { where(state: :active).order(position: :asc, created_at: :asc) }

  enum state: { inactive: 0, active: 1 }
  enum status: { pending: 0, latest: 1, live: 2, improved: 3, deprecated: 4, disabled: 5}
  enum category: { recruiting: 0, payroll_or_hr: 1, productivity: 2, authentication: 3, time_and_attendance: 4, learning_and_development: 5, performance_management: 6, kallidus: 7, benefits: 8 }
  enum data_direction: { s2p: 0, p2s: 1, bi: 2 }
  enum field_mapping_option: { custom_groups: 0, all_fields: 1, integration_fields: 2 }
  enum field_mapping_direction: { sapling_mapping: 0, integration_mapping: 1, both: 2 }

  def logo_url(company_id)
    return unless self.display_logo&.file.present?
    
    file_url = self.display_logo.file_url :logo
    generate_path(company_id, file_url)
  end

  def dialog_logo_url(company_id)
    return unless self.dialog_display_logo&.file.present?

  	generate_path(company_id, self.dialog_display_logo.file_url)
  end

	private

	def generate_path(company_id, path)
		return path unless Rails.env.test? || Rails.env.development?

		port = Rails.env.development? ? 3000 : 3001
		"http://#{Company.find_by_id(company_id).domain}:#{port}#{path}"
	end
end
