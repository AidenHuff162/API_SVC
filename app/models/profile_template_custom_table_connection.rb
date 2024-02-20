class ProfileTemplateCustomTableConnection < ApplicationRecord
  acts_as_paranoid
  validates :profile_template, :position, :custom_table, presence: true
  validate :table_uniqueness, on: :create
  belongs_to :custom_table
  belongs_to :profile_template

  default_scope { order(position: :asc) }
   
  scope :get_position, -> (template_id) { where(profile_template_id: template_id).order(position: :asc).last.try(:position).to_i + 1 }

  after_destroy :reposition_connections

  def reposition_connections
    if self.profile_template.present?
      connection_position = self.position + 1
      connections = self.profile_template.profile_template_custom_table_connections.order(:position).where('position > ?', connection_position)
      connections.each do |conn|
        conn.position = connection_position
        conn.save(validate: false)
        connection_position += 1
      end
    end
  end

  private

  def table_uniqueness
    if self.profile_template.profile_template_custom_table_connections.find_by(custom_table_id: self.custom_table_id).present?
      errors.add(:base, "Table has already been added to this template.")
    end
  end

end
