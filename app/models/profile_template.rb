class ProfileTemplate < ApplicationRecord
  acts_as_paranoid

  validates :company, :name, presence: true
  validates :name, uniqueness: { scope: :company_id }
  
  belongs_to :company
  belongs_to :edited_by, class_name: 'User', foreign_key: :edited_by_id
  belongs_to :process_type
  has_many :profile_template_custom_field_connections
  has_many :profile_template_custom_table_connections
  has_many :users

  before_destroy :destroy_associations
  
  accepts_nested_attributes_for :profile_template_custom_field_connections
  accepts_nested_attributes_for :profile_template_custom_table_connections

  def field_count
    self.profile_template_custom_field_connections.count
  end

  def users_count
    if self.process_type.name == "Onboarding"
      self.company.users.where(onboarding_profile_template_id: self.id).count
    elsif self.process_type.name == "Offboarding"
      self.company.users.where(offboarding_profile_template_id: self.id).count
    end
  end

  def edited_by_name
    self.edited_by.try(:display_name) || "Sapling Migration"
  end

  def location_names
    if self.meta && self.meta["location_id"]
      if self.meta["location_id"][0] == "all"
        []
      else
        self.company.locations.where(id: self.meta["location_id"]).pluck(:name) rescue []
      end
    end
  end

  def team_names
    if self.meta && self.meta["team_id"]
      if self.meta["team_id"][0] == "all"
        []
      else
        self.company.teams.where(id: self.meta["team_id"]).pluck(:name) rescue []
      end
    end
  end

  def status_names
    if self.meta && self.meta["employee_type"]
      if self.meta["employee_type"][0] == "all"
        []
      else
        CustomFieldOption.where(id: self.meta["employee_type"]).pluck(:option)
      end
    end
  end

  def duplicate(current_company)
    new_template = self.dup
    self.profile_template_custom_table_connections.each do |conn|
      new_template.profile_template_custom_table_connections << conn.dup
    end
    self.profile_template_custom_field_connections.each do |conn|
      new_template.profile_template_custom_field_connections << conn.dup
    end
    new_template.name = DuplicateNameService.call(self.name, current_company.profile_templates)
    new_template.save
    new_template
  end

  def reposition_field_connections(moved_connection, custom_field)
    profile_template_connections = self.profile_template_custom_field_connections.includes(:custom_field)
    source_section = custom_field.section_before_last_save
    if source_section.present?
      source_custom_field_connections = profile_template_connections.joins(:custom_field).where(custom_fields: {section: source_section}).where.not(custom_fields: {section: nil})
      source_default_fields = self.company.prefrences["default_fields"].select { |default_field| default_field["section"] == source_section && default_field["profile_setup"] == "profile_fields" }
      source_default_field_connections = profile_template_connections.where(default_field_id: source_default_fields.map { |df| df["id"] })
      source_connections = [].concat(source_custom_field_connections).concat(source_default_field_connections).sort_by { |conn| conn.position }
      source_connections.each.with_index do |conn, index|
        conn.update_column(:position, index)
      end
    end

    destination_section = custom_field.section
    if destination_section.present?
      destination_custom_field_connections = profile_template_connections.joins(:custom_field).where(custom_fields: {section: destination_section}).where.not(custom_fields: {section: nil})
      destination_default_fields = self.company.prefrences["default_fields"].select { |default_field| default_field["section"] == destination_section && default_field["profile_setup"] == "profile_fields" }
      destination_default_field_connections = profile_template_connections.where(default_field_id: destination_default_fields.map { |df| df["id"] })
      destination_connections = [].concat(destination_custom_field_connections).concat(destination_default_field_connections).sort_by { |conn| conn.position }
      moved_connection.update_column(:position, destination_connections[-1].position + 1)
    end
    true
  end

  def delete_removed_connections(table_connections, field_connections)
    table_connections_to_destroy = self.profile_template_custom_table_connections.where.not(id: table_connections.map { |conn| conn[:id] if conn[:id].present? })
    field_connections_to_destroy = self.profile_template_custom_field_connections.where.not(id: field_connections.map { |conn| conn[:id] if conn[:id].present? })
    
    begin
      cf_ids = []
      pf_ids = []
      if field_connections_to_destroy.present?
        field_connections_to_destroy.map { |conn| conn.custom_field_id.present? ? cf_ids.push(conn.custom_field_id) : pf_ids.push(conn.default_field_id) }
        CustomSections::DestroyRequestedFieldsJob.perform_async(cf_ids, pf_ids, self.company&.id)
      end
    rescue Exception => e
      create_general_logging(self.company, 'Destroy Requested Fields on Template update', {data: field_connections_to_destroy&.pluck(:custom_field_id, :default_field_id), cf_ids: cf_ids, pf_ids: pf_ids, error: e.message})
    ensure
      table_connections_to_destroy.delete_all
      field_connections_to_destroy.delete_all
    end
  end

  def custom_fields
    self.company.custom_fields.where(id: self.profile_template_custom_field_connections.pluck(:custom_field_id))
  end

  def create_general_logging(company, action, data, type='Overall')
    general_logging = LoggingService::GeneralLogging.new
    general_logging.create(company, action, data, type)
  end

  private

  def destroy_associations
    self.profile_template_custom_field_connections.with_deleted.find_each { |con| con.really_destroy! }
    self.profile_template_custom_table_connections.with_deleted.find_each { |con| con.really_destroy! }
  end

end
