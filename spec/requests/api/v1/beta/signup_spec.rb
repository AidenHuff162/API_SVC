require 'swagger_helper'

RSpec.describe 'api/v1/beta/signup', type: :request do

  path '/api/v1/beta/adminsignup' do
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    post('Create signup') do
      tags 'Signup'
      response(200, 'successful') do

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

  path '/api/v1/beta/userlogin' do
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    get('Authorize signup') do
      tags 'Signup'
      response(200, 'successful') do

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

  path '/api/v1/beta/passwordstrength' do
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    get('Password strength signup') do
      tags 'Signup'
      response(200, 'successful') do

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
