require 'swagger_helper'

RSpec.describe 'api/v1/beta/groupfields', type: :request do

  path '/api/v1/beta/groupfields/group_fields' do
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    get('Groupfields') do
      tags 'Groupfields'
      response(200, 'successful') do
        description "Return the list of all the Groupfields."
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
