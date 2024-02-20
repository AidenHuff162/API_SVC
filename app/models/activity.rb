class Activity < ApplicationRecord
  acts_as_paranoid
  belongs_to :activity, polymorphic: true
  belongs_to :agent, class_name: 'User', foreign_key: :agent_id
  belongs_to :workspace
end
