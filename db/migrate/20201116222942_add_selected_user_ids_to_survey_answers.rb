class AddSelectedUserIdsToSurveyAnswers < ActiveRecord::Migration[5.1]
  def change
    add_column :survey_answers, :selected_user_ids, :string, array: true
  end
end
