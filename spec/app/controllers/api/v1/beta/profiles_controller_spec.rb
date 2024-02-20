require 'rails_helper'

RSpec.describe Api::V1::Beta::ProfilesController, type: :controller do
  let(:company) { create(:company, subdomain: 'profiles') }
  let(:other_company) { create(:company, subdomain: 'otherprofiles') }
  let(:user) { create(:user, company: company) }
  let(:api_key) { create(:api_key, company: company) }
  let(:workstream) { create(:workstream, company: company) }
  let!(:user) { create(:user, company: company) }

  before do
    @key = JsonWebToken.encode({company_id: company.id, Time: Time.now.to_i})
    api_key.key = SCrypt::Password.create(@key)
    api_key.save!
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe 'GET #fields' do
    context 'not get fields' do
      context 'it should not get fields if token is not present' do
        it 'should reutrn unauthorized status' do
          get :fields, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not get fields if token is incorrect' do
        it 'should reutrn unauthorized status' do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials('1234abc')
          get :fields, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not get fields of other company' do
        it 'should reutrn unauthorized status' do
          allow(controller).to receive(:current_company).and_return(other_company)
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :fields, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not get fields if token exists but key does not exist' do
        it 'should reutrn unauthorized status' do
          key1 = JsonWebToken.encode({company_id: company.id, Time: (Time.now + 10.minutes).to_i})
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(key1)
          get :fields, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not get fields if field id is not present' do
        it 'should reutrn unauthorized status' do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :fields, params: { id: 'aabbcc' }, format: :json
          expect(JSON.parse(response.body)['status']).to eq(422)
          expect(JSON.parse(response.body)['message']).to eq('Invalid Field ID')
        end
      end
    end

    context 'get fields' do
      context 'it should get meta data of custom fields and preference fields if field id is not present' do
        before do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :fields, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return MCQ fields array with necessary key counts' do
          fields = @body.select{|field| field["type"] == "Mcq" }

          expect(fields.count).to eq(12)
          expect(fields.first.keys.count).to eq(5)
          expect(fields.first.keys).to eq(["id", "name", "section", "type", "options"])
        end

        it 'It should return Sub custom Field fields array with necessary key counts' do
          fields = @body.select{|field| field["type"] == "Address" }

          expect(fields.count).to eq(1)
          expect(fields.first.keys.count).to eq(5)
          expect(fields.first.keys).to eq(["id", "name", "section", "type", "sub_fields"])
        end

        it 'It should return simple fields array with necessary key counts' do
          fields = @body.select{|field| field["type"] == "Short Text" }

          expect(fields.count).to eq(16)
          expect(fields.first.keys.count).to eq(4)
          expect(fields.first.keys).to eq(["id", "name", "section", "type"])
        end
      end

      context 'it should get first name field data without applying limit' do
        before do
          10.times do
            create(:user, company: company)
          end

          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :fields, params: { id: 'first_name' }, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return first page, total page count and total users' do
          expect(@body['current_page']).to eq(1)
          expect(@body['total_pages']).to eq(1)
          expect(@body['total_users']).to eq(11)
        end

        it 'It should return users array with necessary key counts' do
          expect(@body['users'].count).to eq(11)
          expect(@body['users'].first.keys.count).to eq(7)
          expect(@body['users'].first.keys).to eq(["id", "guid", "first_name", "role_information", "employment_status", "compensation", "section"])
        end
      end

      context 'it should get first name field data with applying limit' do
        before do
          10.times do
            create(:user, company: company)
          end

          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :fields, params: { id: 'first_name', limit: 5 }, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return first page, total page count and total users' do
          expect(@body['current_page']).to eq(1)
          expect(@body['total_pages']).to eq(3)
          expect(@body['total_users']).to eq(11)
        end

        it 'It should return users array with necessary key counts' do
          expect(@body['users'].count).to eq(5)
          expect(@body['users'].first.keys.count).to eq(7)
          expect(@body['users'].first.keys).to eq(["id", "guid", "first_name", "role_information", "employment_status", "compensation", "section"])
        end
      end

      context 'it should get users with applying limit and page number' do
        before do
          10.times do
            create(:user, company: company)
          end

          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :fields, params: { id: 'first_name', limit: 5, page: 3 }, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return first page, total page count and total users' do
          expect(@body['current_page']).to eq(3)
          expect(@body['total_pages']).to eq(3)
          expect(@body['total_users']).to eq(11)
        end

        it 'It should return users array with necessary key counts' do
          expect(@body['users'].count).to eq(1)
          expect(@body['users'].first.keys.count).to eq(7)
          expect(@body['users'].first.keys).to eq(["id", "guid", "first_name", "role_information", "employment_status", "compensation", "section"])
        end
      end

    end
  end

  describe 'GET #index' do
    context 'not get users fields data' do
      context 'it should not get fields data if token is not present' do
        it 'should reutrn unauthorized status' do
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not get fields data if token is incorrect' do
        it 'should reutrn unauthorized status' do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials('1234abc')
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not get fields data of other company' do
        it 'should reutrn unauthorized status' do
          allow(controller).to receive(:current_company).and_return(other_company)
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not get fields data if token exists but key does not exist' do
        it 'should reutrn unauthorized status' do
          key1 = JsonWebToken.encode({company_id: company.id, Time: (Time.now + 10.minutes).to_i})
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(key1)
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'get users fields data' do
      context 'it should get users fields data without applying any limit and filter' do
        before do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :index, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return users fields data with necessary key and count' do
          expect(@body['users'].count).to eq(1)
          expect(@body['users'].first.keys.count).to eq(43)
          expect(@body['users'].first.keys).to eq(["id", "guid", "start_date", "first_name", "last_name",
                                                   "preferred_name", "job_title", "job_tier", "manager",
                                                   "buddy", "location", "department", "termination_type",
                                                   "eligible_for_rehire", "termination_date", "state",
                                                   "last_day_worked", "company_email", "personal_email",
                                                   "about", "github", "twitter", "linkedin", "profile_photo",
                                                   "role_information", "employment_status", "compensation",
                                                   "home_phone_number", "mobile_phone_number", "food_allergies_preferences",
                                                   "dream_vacation_spot", "favorite_food", "pets_and_animals",
                                                   "t_shirt_size", "social_security_number", "federal_marital_status",
                                                   "date_of_birth", "home_address", "gender", "race_ethnicity",
                                                   "emergency_contact_name", "emergency_contact_relationship",
                                                   "emergency_contact_number"])
        end
      end

      context 'it should get users fields data with applying limit' do
        before do
          5.times do
            create(:user, company: company)
          end
          5.times do
            create(:offboarding_user, company: company)
          end
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :index, params: { limit: 5 }, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return first page, total page count and total users' do
          expect(@body['current_page']).to eq(1)
          expect(@body['total_pages']).to eq(3)
          expect(@body['total_users']).to eq(11)
        end

        it 'It should return users fields data with necessary key and count' do
          expect(@body['users'].count).to eq(5)
          expect(@body['users'].first.keys.count).to eq(43)
          expect(@body['users'].first.keys).to eq(["id", "guid", "start_date", "first_name", "last_name",
                                                   "preferred_name", "job_title", "job_tier", "manager",
                                                   "buddy", "location", "department", "termination_type",
                                                   "eligible_for_rehire", "termination_date", "state",
                                                   "last_day_worked", "company_email", "personal_email",
                                                   "about", "github", "twitter", "linkedin", "profile_photo",
                                                   "role_information", "employment_status", "compensation",
                                                   "home_phone_number", "mobile_phone_number", "food_allergies_preferences",
                                                   "dream_vacation_spot", "favorite_food", "pets_and_animals",
                                                   "t_shirt_size", "social_security_number", "federal_marital_status",
                                                   "date_of_birth", "home_address", "gender", "race_ethnicity",
                                                   "emergency_contact_name", "emergency_contact_relationship",
                                                   "emergency_contact_number"])
        end
      end

      context 'it should get users fields data with applying limit and filter' do
        before do
          5.times do
            create(:user, company: company)
          end
          5.times do
            create(:offboarding_user, company: company)
          end
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :index, params: { limit: 5, status: 'active' }, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return first page, total page count and total users' do
          expect(@body['current_page']).to eq(1)
          expect(@body['total_pages']).to eq(2)
          expect(@body['total_users']).to eq(6)
        end

        it 'It should return users fields data with necessary key and count' do
          expect(@body['users'].count).to eq(5)
          expect(@body['users'].first.keys.count).to eq(43)
          expect(@body['users'].first.keys).to eq(["id", "guid", "start_date", "first_name", "last_name",
                                                   "preferred_name", "job_title", "job_tier", "manager",
                                                   "buddy", "location", "department", "termination_type",
                                                   "eligible_for_rehire", "termination_date", "state",
                                                   "last_day_worked", "company_email", "personal_email",
                                                   "about", "github", "twitter", "linkedin", "profile_photo",
                                                   "role_information", "employment_status", "compensation",
                                                   "home_phone_number", "mobile_phone_number", "food_allergies_preferences",
                                                   "dream_vacation_spot", "favorite_food", "pets_and_animals",
                                                   "t_shirt_size", "social_security_number", "federal_marital_status",
                                                   "date_of_birth", "home_address", "gender", "race_ethnicity",
                                                   "emergency_contact_name", "emergency_contact_relationship",
                                                   "emergency_contact_number"])
        end
      end
    end
  end

  describe 'GET #show' do
    context 'not get user fields data' do
      context 'it should not get user fields data if token is not present' do
        it 'should reutrn unauthorized status' do
          get :show, params: { id: user.guid }, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not get user fields data if token is incorrect' do
        it 'should reutrn unauthorized status' do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials('1234abc')
          get :show, params: { id: user.guid }, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not get user fields data of other company' do
        it 'should reutrn unauthorized status' do
          allow(controller).to receive(:current_company).and_return(other_company)
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :show, params: { id: user.guid }, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not get user fields data if token exists but key does not exist' do
        it 'should reutrn unauthorized status' do
          key1 = JsonWebToken.encode({company_id: company.id, Time: (Time.now + 10.minutes).to_i})
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(key1)
          get :show, params: { id: user.guid }, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'get user fields data' do
      context 'it should get user fields data' do
        before do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :show, params: { id: user.guid }, format: :json
          @body = JSON.parse(response.body)
        end

        it 'It should return success status and log data' do
          expect(response).to have_http_status(:success)
          expect(ApiLogging.count).to eq(1)
        end

        it 'It should return user fields data with necessary key and count' do
          expect(@body['user'].count).to eq(43)
          expect(@body['user'].keys).to eq(["id", "guid", "start_date", "first_name", "last_name",
                                            "preferred_name", "job_title", "job_tier", "manager",
                                            "buddy", "location", "department", "termination_type",
                                            "eligible_for_rehire", "termination_date", "state",
                                            "last_day_worked", "company_email", "personal_email",
                                            "about", "github", "twitter", "linkedin", "profile_photo",
                                            "role_information", "employment_status", "compensation",
                                            "home_phone_number", "mobile_phone_number", "food_allergies_preferences",
                                            "dream_vacation_spot", "favorite_food", "pets_and_animals",
                                            "t_shirt_size", "social_security_number", "federal_marital_status",
                                            "date_of_birth", "home_address", "gender", "race_ethnicity",
                                            "emergency_contact_name", "emergency_contact_relationship",
                                            "emergency_contact_number"])
        end
      end
    end
  end

  describe 'post #create' do
    before do
      @params = {
        company_email: 'abc@gamil.com',
        personal_email: 'abc@gamil.com',
        first_name: 'first name',
        last_name: 'create name',
        start_date: 1.day.ago.to_date,
        status: 'active',
        manager: user.guid,
        preferred_name: 'preferred name',
        about: 'about'
        }
      request.env["HTTP_ACCEPT"] = 'application/json'
    end

    context 'not create profile' do
      context 'it should not create profile if token is not present' do
        it 'should reutrn unauthorized status' do
          post :create, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not create profile if token is incorrect' do
        it 'should reutrn unauthorized status' do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials('1234abc')
          post :create, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not create profile of other company' do
        it 'should reutrn unauthorized status' do
          allow(controller).to receive(:current_company).and_return(other_company)
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          post :create, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not create profile if token exists but key does not exist' do
        it 'should reutrn unauthorized status' do
          key1 = JsonWebToken.encode({company_id: company.id, Time: (Time.now + 10.minutes).to_i})
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(key1)
          post :create, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not create profile if params are invalid' do
        before do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
        end

        it 'It should return bad request error if any required fields are missing' do
          post :create, params: { first_name: 'first_name', last_name: 'last_name' }, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Required attributes are missing')
        end

        it 'It should return bad request error if first name is not present' do
          @params[:first_name] = nil
          post :create, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Can not update. Attribute(first_name) value is required')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end

        it 'It should return bad request error if last name is not present' do
          @params[:last_name] = nil
          post :create, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Can not update. Attribute(last_name) value is required')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end

        it 'It should return bad request error if company email is not present' do
          @params[:company_email] = nil
          post :create, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Can not update. Attribute(company_email) is required')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end

        it 'It should return bad request error if personal email is invalid' do
          @params[:personal_email] = 'asdas.com'
          post :create, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Can not update. Attribute(personal_email) email is invalid')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end


        it 'It should return bad request error if company email is invalid' do
          @params[:company_email] = 'asdas.com'
          post :create, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Can not update. Attribute(company_email) email is invalid')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end

        it 'It should return bad request error if start date is invalid' do
          @params[:start_date] = '11-21-1234'
          post :create, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Can not update. Attribute(start_date) format is invalid. It should be in foramt yyyy-mm-dd')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end

        it 'It should return bad request error if status is invalid' do
          @params[:status] = 234
          post :create, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Invalid Value for attribute(status)')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end

        it 'It should return bad request error if manager id inavlid' do
          @params[:manager] = "123"
          post :create, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('User doesnot exits for attribute(manager)')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end

        it 'It should return bad request error if location id is invalid' do
          @params[:location] = 123
          post :create, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Location doesnot exits for attribute(location) value')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end
      end
    end

    context 'create profile' do
      before do
        request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
        post :create, params: @params, format: :json
        @body = JSON.parse(response.body)
      end

      it 'It should return success status and log data' do
        expect(response).to have_http_status(:success)
        expect(ApiLogging.count).to eq(1)
        expect(@body['message']).to eq('Created successfully')
        expect(@body['status']).to eq(200)
        expect(@body['guid']).not_to eq('')
      end
    end
  end

  describe 'post #create, #update (with custom table)' do
    let(:custom_company) { create(:company, subdomain: 'custom_profiles', is_using_custom_table: true) }
    let(:api_key) { create(:api_key, company: custom_company) }
    let(:manager) { create(:user, company: custom_company) }

    before do
      @role_information = custom_company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information])
      @phone_field = create(:phone_field, company: custom_company, custom_table: @role_information)
      @employment_status = custom_company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status])
      request.env["HTTP_ACCEPT"] = 'application/json'

      @key = JsonWebToken.encode({company_id: custom_company.id, Time: Time.now.to_i})
      api_key.key = SCrypt::Password.create(@key)
      api_key.save!
      allow(controller).to receive(:current_company).and_return(custom_company)
    end

    context 'create profile' do
      before do
        @params = {
          company_email: 'abc@gamil.com',
          personal_email: 'abc@gamil.com',
          first_name: 'first name',
          last_name: 'create name',
          start_date: 1.day.ago.to_date,
          status: 'active',
          manager: manager.guid,
          preferred_name: 'preferred name',
          about: 'about',
          "#{@phone_field.api_field_id}": "{country: 'PAK', area_code: '300', phone: '4567890'}" 
        }
        request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
        post :create, params: @params, format: :json
        @body = JSON.parse(response.body)
      end

      it 'It should return success status and log data and create custom table user snapshtos' do
        expect(response).to have_http_status(:success)
        user = custom_company.users.find_by(personal_email: @params[:personal_email])
        expect(ApiLogging.count).to eq(1)
        expect(user).not_to eq(nil)
        expect(user.custom_table_user_snapshots.count).to eq(2)
        expect(user.custom_table_user_snapshots.where(custom_table: @role_information).take.integration_type).to eq('public_api')
        expect(user.custom_table_user_snapshots.where(custom_table: @role_information).take.custom_snapshots.where(custom_field_id: @phone_field.id).take.custom_field_value).to eq("PAK|300|4567890")
        expect(user.custom_table_user_snapshots.where(custom_table: @role_information).take.custom_snapshots.where(preference_field_id: 'man').take.custom_field_value.to_i).to eq(manager.id)
        expect(user.custom_table_user_snapshots.where(custom_table: @employment_status).take.custom_snapshots.where(preference_field_id: 'st').take.custom_field_value).to eq('active')
        expect(@body['message']).to eq('Created successfully')
        expect(@body['status']).to eq(200)
        expect(@body['guid']).not_to eq('')
      end
    end
    
    context 'update profile' do
      before do
        @location = create(:location, company: custom_company)
        @params = {
          id: manager.guid,
          personal_email: 'abc@gamil.com',
          status: 'inactive',
          last_day_worked: '2020-04-04',
          termination_date: '2020-05-04',
          location: @location.name
        }
        request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
        post :update, params: @params, format: :json
        @body = JSON.parse(response.body)
      end

      it 'It should return success status and log data and create custom table user snapshtos' do
        expect(response).to have_http_status(:success)
        user = custom_company.users.find_by(personal_email: @params[:personal_email])
        expect(ApiLogging.count).to eq(1)
        expect(user).not_to eq(nil)
        expect(user.custom_table_user_snapshots.count).to eq(2)
        expect(user.custom_table_user_snapshots.where(custom_table: @role_information).take.integration_type).to eq('public_api')
        expect(user.custom_table_user_snapshots.where(custom_table: @role_information).take.custom_snapshots.where(preference_field_id: 'loc').take.custom_field_value.to_i).to eq(@location.id)
        expect(user.custom_table_user_snapshots.where(custom_table: @employment_status).take.custom_snapshots.where(preference_field_id: 'st').take.custom_field_value).to eq('inactive')
        expect(user.custom_table_user_snapshots.where(custom_table: @employment_status).take.terminated_data["last_day_worked"]).to eq("2020-04-04")
        expect(@body['message']).to eq('Updated successfully')
        expect(@body['status']).to eq(200)
        expect(@body['guid']).not_to eq('')
      end
    end
  end

  describe 'post #update' do
    before do
      @params = {
        id: user.guid,
        company_email: 'abc@gamil.com',
        personal_email: 'abc@gamil.com',
        first_name: 'first name',
        last_name: 'create name',
        start_date: 1.day.ago.to_date,
        status: 'active',
        preferred_name: 'preferred name',
        about: 'about'
        }
      request.env["HTTP_ACCEPT"] = 'application/json'
    end

    context 'not update profile' do
      context 'it should not update profile if token is not present' do
        it 'should reutrn unauthorized status' do
          post :update, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not update profile if token is incorrect' do
        it 'should reutrn unauthorized status' do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials('1234abc')
          post :update, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not update profile of other company' do
        it 'should reutrn unauthorized status' do
          allow(controller).to receive(:current_company).and_return(other_company)
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          post :update, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'It should not update profile if token exists but key does not exist' do
        it 'should reutrn unauthorized status' do
          key1 = JsonWebToken.encode({company_id: company.id, Time: (Time.now + 10.minutes).to_i})
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(key1)
          post :update, params: @params, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'it should not update profile if params are invalid' do
        before do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
        end

        it 'It should return bad request error if user id is invalid' do
          @params[:id] = 1234
          post :update, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Invalid User ID')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end

        it 'It should return bad request error if first name is not present' do
          @params[:first_name] = nil
          post :update, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Can not update. Attribute(first_name) value is required')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end

        it 'It should return bad request error if last name is not present' do
          @params[:last_name] = nil
          post :update, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Can not update. Attribute(last_name) value is required')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end

        it 'It should return bad request error if company email is not present' do
          @params[:company_email] = nil
          post :update, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Can not update. Attribute(company_email) is required')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end

        it 'It should return bad request error if personal email is invalid' do
          @params[:personal_email] = 'asdas.com'
          post :update, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Can not update. Attribute(personal_email) email is invalid')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end


        it 'It should return bad request error if company email is invalid' do
          @params[:company_email] = 'asdas.com'
          post :update, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Can not update. Attribute(company_email) email is invalid')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end

        it 'It should return bad request error if start date is invalid' do
          @params[:start_date] = '11-21-1234'
          post :update, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Can not update. Attribute(start_date) format is invalid. It should be in foramt yyyy-mm-dd')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end

        it 'It should return bad request error if status is invalid' do
          @params[:status] = 234
          post :update, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Invalid Value for attribute(status)')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end

        it 'It should return bad request error if manager id inavlid' do
          @params[:manager] = "123"
          post :update, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('User doesnot exits for attribute(manager)')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end

        it 'It should return bad request error if manager is user himself' do
          @params[:manager] = user.guid
          post :update, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('User cannot be a manager of himself')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end

        it 'It should return bad request error if location id is invalid' do
          @params[:location] = 123
          post :update, params: @params, format: :json
          expect(ApiLogging.count).to eq(1)
          expect(JSON.parse(response.body)['message']).to eq('Location doesnot exits for attribute(location) value')
          expect(JSON.parse(response.body)['status']).to eq(400)
        end
      end
    end

    context 'update profile' do
      before do
        request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
        post :update, params: @params, format: :json
        @body = JSON.parse(response.body)
      end

      it 'It should return success status and log data' do
        expect(response).to have_http_status(:success)
        expect(ApiLogging.count).to eq(1)
        expect(@body['message']).to eq('Updated successfully')
        expect(@body['status']).to eq(200)
        expect(@body['guid']).not_to eq('')
      end
    end
  end
end
