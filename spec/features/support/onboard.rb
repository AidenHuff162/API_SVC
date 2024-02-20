module Onboard
  extend Capybara::DSL

  STEPS = [:welcome, :our_story, :our_team]

  module_function

  def step_completed(step)
    index = STEPS.find_index(step)

    page.evaluate_script "localStorage.setItem('onboarding_step', #{index + 1})"
    page.evaluate_script "localStorage.setItem('onboarding_last_step', #{index + 1})"
    visit current_path
  end
end
