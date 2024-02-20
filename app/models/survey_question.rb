class SurveyQuestion < ApplicationRecord
  acts_as_paranoid
  validates :survey, :question_text, :position, :question_type, presence: true
  belongs_to :survey
  validates :question_text, uniqueness: { scope: :survey_id }

  enum question_type: { short_text: 0, long_text: 1, likert: 2, mcq: 3, person_lookup: 4 }
  enum category: { joining_decision: 0, preboarding: 1, onboarding: 2, engagement: 3,
                   induction: 4, alignment: 5, manager_effectiveness: 6, self_efficacy: 7,
                   exit_decision: 8, manager_reflection: 9, job_reflection: 10, company_reflection: 11,
                   well_being: 12, relationships: 13, support: 14, strengths: 15, improvements: 16,
                   self_awareness: 17, drive: 18, communication: 19, leadership: 20, teamwork: 21,
                   information_flow: 22, communication_frequency: 23, helpfulness: 24, energy_level: 25,
                   problem_solving: 26, innovation: 27, decision_making: 28, knowledge_skills_awareness: 29 }

end
