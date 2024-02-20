class AddCategoryToSurveyQuestions < ActiveRecord::Migration[5.1]
  def change
    add_column :survey_questions, :category, :integer
  end
end
