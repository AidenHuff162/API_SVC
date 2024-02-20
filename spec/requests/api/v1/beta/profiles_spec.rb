require 'swagger_helper'

RSpec.describe 'api/v1/beta/profiles', type: :request do

  path '/api/v1/beta/profiles/fields/{id}' do
    # You'll want to customize the parameter types...
    parameter name: 'id', in: :path, type: :string, description: 'id'
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    get('Field profile') do
      tags 'Users'
      response(200, 'successful') do
        let(:id) { '123' }
        description "Returns an individual profile field for all users at your company.\n These will be alphanumeric for permanent fields (i.e. last_name) and Fields IDs for custom fields (i.e. PFID34357507802737).\n Fields IDs can be retrieved from the Get all Fields request."
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

  path '/api/v1/beta/profiles/get_sapling_profile' do
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    get('Get sapling profile') do
      tags 'Users'
      response(200, 'successful') do
        description "Returns the information about a user in the Sapling platform.\n You can find the GUID by using the Get all Users request, or by running a report inside of Sapling."
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

  path '/api/v1/beta/profiles/fields' do
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    get('All fields profile') do
      tags 'Users'
      response(200, 'successful') do
        description "Returns a list of API-transferable profile fields at your company.\n The response will include the id, name, section and field-type."
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

  path '/api/v1/beta/profiles' do
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    parameter name: 'Content-Type', in: :header, type: :string, required: true, description: 'application/x-www-form-urlencoded'
    get('List profiles') do
      tags 'Users'
      response(200, 'successful') do
        description "Returns all users in the Sapling account.\n This will include GUIDs which can then be used to call Sapling's API for individual user information."
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

    post('Create profile') do
      tags 'Users'
      response(200, 'successful') do
        description "Creates a User in your Sapling Account.

          The required fields to create a new User are:
      
          - Company Email
          - First Name
          - Preffered Name
          - Last Name
          - Start Date
          - Job Title
          - Department
          - Location 
          - Status
      
          For a complete list of fields, use the Get all Fields request. Include the API Field ID as the Key; if no API Field ID is available, use the descriptive name as shown."
        consumes 'multipart/form-data'
        parameter name: :pending_hire, in: :formData, schema: {
        type: :object,
        properties: {
            company_email: { type: :string },
            first_name: { type: :string },
            preferred_name: { type: :string },
            last_name: { type: :string },
            start_date: { type: :string },
            job_title: { type: :string },
            Department: { type: :string },
            Location: { type: :string },
            status: { type: :string },
         
        },
        required: %w[company_email first_name preferred_name last_name start_date job_title Department Location status]
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

  path '/api/v1/beta/profiles/{id}' do
    # You'll want to customize the parameter types...
    parameter name: 'id', in: :path, type: :string, description: 'id'
    parameter name: 'Authorization', in: :header, type: :string, required: true, description: 'Bearer{token}'
    parameter name: 'Content-Type', in: :header, type: :string, required: true, description: 'application/x-www-form-urlencoded'
    get('Show profile') do
      tags 'Users'
      response(200, 'successful') do
        description "Returns the information about a user in the Sapling platform.\n You can find the GUID by using the Get all Users request, or by running a report inside of Sapling."
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

    patch('Update profile') do
      tags 'Users'
      response(200, 'successful') do
        description "Updates a user in your Sapling account.\n Use the GUID to identity which user you would like to update and the Field ID for each field you want to update.\n The GUIDs for users can be obtained from the Users resource and the Field IDs can be obtained from the Fields resource."
        let(:id) { '123' }
        consumes 'multipart/form-data'
        parameter name: :pending_hire, in: :formData, schema: {
        type: :object,
        properties: {
            company_email: { type: :string },
            first_name: { type: :string },
            preferred_name: { type: :string },
            last_name: { type: :string },
            start_date: { type: :string },
            job_title: { type: :string },
            Department: { type: :string },
            Location: { type: :string },
            status: { type: :string },
         
        },
        required: %w[company_email first_name preferred_name last_name start_date job_title Department Location status]
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

    put('Update profile') do
      tags 'Users'
      response(200, 'successful') do 
        description "Updates a user in your Sapling account.\n Use the GUID to identity which user you would like to update and the Field ID for each field you want to update.\n The GUIDs for users can be obtained from the Users resource and the Field IDs can be obtained from the Fields resource."

        let(:id) { '123' }
        consumes 'multipart/form-data'
        parameter name: :pending_hire, in: :formData, schema: {
        type: :object,
        properties: {
            company_email: { type: :string },
            first_name: { type: :string },
            preferred_name: { type: :string },
            last_name: { type: :string },
            start_date: { type: :string },
            job_title: { type: :string },
            Department: { type: :string },
            Location: { type: :string },
            status: { type: :string },
         
        },
        required: %w[company_email first_name preferred_name last_name start_date job_title Department Location status]
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
