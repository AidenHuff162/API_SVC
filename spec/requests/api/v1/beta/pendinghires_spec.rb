require 'swagger_helper'

RSpec.describe 'api/v1/beta/pendinghires', type: :request do

  path '/api/v1/beta/pendinghires' do
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    get('List pendinghires') do
      tags 'Pending Hires'
      response(200, 'successful') do
        description "Gets all Pending hires in Sapling."
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

    post('Create pendinghire') do
      tags 'Pending Hires'
      response(200, 'successful') do
        description "Create a new pending hire in Sapling. Once created, a Sapling user can initiate onboarding for this pending hire, converting them to a User.

          Required fields in the payload are:

          - personalEmail (personal email of the pending hire)
          - firstName (first name of the pending hire)
          - lastName (last name of the pending hire)
          - startDate (expected start date of the pending hire)
          - source (caller's root web URL e.g. https://www.saplinghr.com)
          - prefferedName (prefferedName of the pending hire)
          - startDate (Starting Date of the pending hire)
          - jobTitle (jobTitle of the pending hire)
          - department (department of the pending hire)
          - location (location of the pending)
          - status (status of the pending hire)
          - employmentStatus (employmentStatus of the pending hire)
          - source (source for the pending hire)

          Note that you may want to supply preferredName equal to firstName if preferredName isn't explicitly defined in the source application to improve searchability and display of the pending hire in Sapling."
        consumes 'multipart/form-data'
        parameter name: :pending_hire, in: :formData, schema: {
        type: :object,
        properties: {
          personalEmail: { type: :string },
          firstName: { type: :string },
          preferredName: { type: :string },
          lastName: { type: :string },
          startDate: { type: :string },
          jobTitle: { type: :string },
          department: { type: :string },
          location: { type: :string },
          status: { type: :string },
          employmentStatus: { type: :string },
          source: { type: :string },
        },
        required: %w[personalEmail firstName preferredName lastName startDate jobTitle department location status employmentStatus source]
        }
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

  path '/api/v1/beta/pendinghires/{id}' do
    # You'll want to customize the parameter types...
    parameter name: 'id', in: :path, type: :string, description: 'id'
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    get('Show pendinghire') do
      tags 'Pending Hires'
      response(200, 'successful') do
        let(:id) { '123' }
        description "Gets a single pending hire in Sapling."
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

    patch('Update pendinghire') do
      tags 'Pending Hires'
      response(200, 'successful') do
        let(:id) { '123' }
        description "Update an existing pending hire in Sapling."
        consumes 'multipart/form-data'
        parameter name: :pending_hire, in: :formData, schema: {
        type: :object,
        properties: {
          personalEmail: { type: :string },
          firstName: { type: :string },
          preferredName: { type: :string },
          lastName: { type: :string },
          startDate: { type: :string },
          jobTitle: { type: :string },
          department: { type: :string },
          location: { type: :string },
          status: { type: :string },
          employmentStatus: { type: :string },
          source: { type: :string },
        },
        required: %w[personalEmail firstName preferredName lastName startDate jobTitle department location status employmentStatus source]
        }
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

    put('Update pendinghire') do
       tags 'Pending Hires'
      response(200, 'successful') do
        let(:id) { '123' }
        description "Update an existing pending hire in Sapling."
        consumes 'multipart/form-data'
        parameter name: :pending_hire, in: :formData, schema: {
        type: :object,
        properties: {
          personalEmail: { type: :string },
          firstName: { type: :string },
          preferredName: { type: :string },
          lastName: { type: :string },
          startDate: { type: :string },
          jobTitle: { type: :string },
          department: { type: :string },
          location: { type: :string },
          status: { type: :string },
          employmentStatus: { type: :string },
          source: { type: :string },
        },
        required: %w[personalEmail firstName preferredName lastName startDate jobTitle department location status employmentStatus source]
        }
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
