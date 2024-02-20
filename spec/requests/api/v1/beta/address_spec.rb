require 'swagger_helper'

RSpec.describe 'api/v1/beta/address', type: :request do

  path '/api/v1/beta/address/countries' do
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    get('Countries address') do
      tags 'Addresses'
      response(200, 'successful') do
        description "Return the list of all the Countries."
        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/beta/address/states' do
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    get('States address') do
      tags 'Addresses'
      response(200, 'successful') do
        description "Return the list of all the States."
        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end
end
