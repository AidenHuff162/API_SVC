require 'swagger_helper'

RSpec.describe 'api/v1/beta/tasks', type: :request do

  path '/api/v1/beta/tasks' do
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    get('List tasks') do
      tags 'Tasks'
      response(200, 'successful') do
        description "Get a list of all tasks for a specific user based on email address"
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

  path '/api/v1/beta/tasks/{id}' do
    # You'll want to customize the parameter types...
    parameter name: 'id', in: :path, type: :string, description: 'id'
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    patch('Update task') do
      tags 'Tasks'
      response(200, 'successful') do
        description "Update tasks for a specific user."
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

    put('Update task') do
      tags 'Tasks'
      response(200, 'successful') do
        description "Update tasks for a specific user."
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

    delete('Delete task') do
      tags 'Tasks'
      response(200, 'successful') do
        description "Delete tasks for a specific user."
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
