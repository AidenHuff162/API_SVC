FactoryGirl.define do
  factory :webhook_event do
    status :succeed
    response_status 200 
    request_body { {request: 'data', webhook_event: {id: 'test'} } }
    response_body { {response: 'ok' } }

    triggered_for { build(:user, company: company) }
    triggered_by { build(:user, company: company) }

    triggered_at { DateTime.now }

    webhook
    company
  end
end