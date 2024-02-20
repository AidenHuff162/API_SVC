require 'swagger_helper'

RSpec.describe 'api/v1/beta/workflows', type: :request do

  path '/api/v1/beta/workflows/tasks' do
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    post('Tasks workflow') do
      tags 'Workflows'
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

  path '/api/v1/beta/workflows' do
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    get('List workflows') do
      tags 'Workflows'
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

    post('Create workflow') do
      tags 'Workflows'
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

  path '/api/v1/beta/workflows/{id}' do
    # You'll want to customize the parameter types...
    parameter name: 'id', in: :path, type: :string, description: 'id'
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    get('Show workflow') do
      tags 'Workflows'
      response(200, 'successful') do
        let(:id) { '123' }

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
