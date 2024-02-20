FactoryGirl.define do
  factory :webhook do
    state :active
    created_from :app
    event :stage_completed
    
    description { Faker::Hipster.sentence }
    
    if Rails.env.development?
      target_url 'https://rocketship.ngrok.io/api/v1/admin/webhooks'
    elsif Rails.env.test?
      target_url 'http://company.domain/api/v1/admin/webhooks'
    end
    
    filters { { "location_id"=>["all"], "team_id"=>["all"], "employee_type"=>["all"] } }
    
    created_by { build(:user, company: company) }
    updated_by { build(:user, company: company) }

    company
  end
end
