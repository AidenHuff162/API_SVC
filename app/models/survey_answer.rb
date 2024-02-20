class SurveyAnswer < ApplicationRecord
  acts_as_paranoid
  validates :survey_question, :task_user_connection, presence: true
  belongs_to :survey_question
  belongs_to :task_user_connection
  validates :survey_question_id, uniqueness: { scope: :task_user_connection_id }

end
