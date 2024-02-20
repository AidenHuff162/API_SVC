class ProcessType < ApplicationRecord

  validates_presence_of :name
  
  has_many :workstreams
  has_many :profile_templates
    
  before_destroy :nullify_associations

  enum entity_type: { Workstream: 0 } 
  
  ONBOARDING = 'Onboarding'

  private

  def nullify_associations
    self.profile_templates.with_deleted.find_each { |pt| pt.update(process_type_id: nil) }
    self.workstreams.with_deleted.find_each { |ws| ws.update(process_type_id: nil) }
  end
end
