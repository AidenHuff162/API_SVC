namespace :add_categories_to_survey_questions do

  task add_categories_to_survey_questions: :environment do
    puts "---- Adding Category data to existing survey questions ----"

    surveys = Survey.where(name: "1st Week Check-In")
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [0, 1]).update_all(category: 0)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [2, 3]).update_all(category: 1)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [4, 5, 6, 7]).update_all(category: 2)

    surveys = Survey.where(name: "1st Month Check-In")
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [0, 1, 2]).update_all(category: 3)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [3, 4, 5, 6, 7]).update_all(category: 4)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [8, 9, 10, 11]).update_all(category: 5)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [12, 13, 14, 15]).update_all(category: 2)

    surveys = Survey.where(name: "90-Day Check-In")
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [0, 1, 2, 3]).update_all(category: 3)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [4, 5]).update_all(category: 5)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [6, 7]).update_all(category: 6)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [8, 9, 10, 11]).update_all(category: 7)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [12, 13, 14, 15]).update_all(category: 2)

    surveys = Survey.where(name: "Exit Survey")
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [0, 1, 2, 3]).update_all(category: 8)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [4, 5, 6, 7]).update_all(category: 9)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [8, 9, 10, 11]).update_all(category: 10)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [12, 13, 14, 15, 16, 17]).update_all(category: 11)

    surveys = Survey.where(name: "Wellness Check-In")
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [0, 1, 2, 3, 4, 5]).update_all(category: 12)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [6, 7]).update_all(category: 13)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [8, 9, 10, 11]).update_all(category: 14)

    surveys = Survey.where(name: "Performance Check-In (Open)")
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [0, 1]).update_all(category: 15)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [2, 3]).update_all(category: 16)

    surveys = Survey.where(name: "Performance Check-In (Measured)")
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [0, 1, 2, 3]).update_all(category: 17)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [4, 5]).update_all(category: 18)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [6, 7]).update_all(category: 19)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [8, 9, 10, 11]).update_all(category: 20)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [12, 13, 14, 15]).update_all(category: 21)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [16, 17]).update_all(category: 15)
    SurveyQuestion.where(survey_id: surveys.pluck(:id), position: [18, 19]).update_all(category: 16)

    puts "---- Completed ----"
  end

end
