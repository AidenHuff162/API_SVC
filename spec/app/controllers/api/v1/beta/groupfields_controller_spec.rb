require 'rails_helper'

RSpec.describe Api::V1::Beta::GroupfieldsController, type: :controller do
  let(:company) { create(:company_with_team_and_location) }
  let(:other_company) { create(:company, subdomain: 'otherprofiles') }
  let(:api_key) { create(:api_key, company: company) }

  before do
    @key = JsonWebToken.encode({company_id: company.id, Time: Time.now.to_i})
    api_key.key = SCrypt::Password.create(@key)
    api_key.save!
    allow(controller).to receive(:current_company).and_return(company)
  end
  describe 'GET #group_fields' do
    context 'not get group_fields' do
      context 'it should not get group_fields if token is not present' do
        it 'should return unauthorized status' do
          get :group_fields, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end
      context 'it should not get group_fields if token is incorrect' do
        it 'should return unauthorized status' do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials('1234abc')
          get :group_fields, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end
      context 'It should not get group_fields of other company' do
        it 'should return unauthorized status' do
          allow(controller).to receive(:current_company).and_return(other_company)
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :group_fields, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end
      context 'It should not get group_fields if token exists but key does not exist' do
        it 'should return unauthorized status' do
          key1 = JsonWebToken.encode({company_id: company.id, Time: (Time.now + 10.minutes).to_i})
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(key1)
          get :group_fields, format: :json
          expect(response).to have_http_status(:unauthorized)
        end
      end
      context 'It should  get group_fields ' do
        it 'should reutrn succes status' do
          request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
          get :group_fields, format: :json
          expect(response).to have_http_status(:success)
        end
      end
    end
    context 'get group_fields' do
      RSpec.shared_examples 'example succes status' do 
        it 'should return success status' do
          expect(response).to have_http_status(:success) 
        end
      end  
      before do
        request.headers['Authorization'] = ActionController::HttpAuthentication::Token.encode_credentials(@key)
        get :group_fields, format: :json
        @body = JSON.parse(response.body)
      end
      context 'it should get group_fields' do      
        include_examples 'example succes status'
        it 'should return group_fields key count and array with necessary keys ' do
          expect(@body.count).to eq(4)
          expect(@body.keys).to eq([  "departments", 
                                      "locations", 
                                      "Employment Status", 
                                      "status"
                                  ])
        end
      end
      context 'it should get employment status group_field data' do        
        include_examples 'example succes status'
        it 'should return employment status group_field key count and array with necessary keys ' do
          employment_status = @body['Employment Status']
          expect(employment_status.first.count).to eq(12)
          expect(employment_status.first.keys).to eq(["name", 
                                                      "description",
                                                        "active", 
                                                        "namely_group_type",
                                                        "namely_group_id",
                                                        "owner_id","position",
                                                        "workday_wid",
                                                        "adp_wfn_us_code_value", 
                                                        "adp_wfn_can_code_value",
                                                        "gsuite_mapping_key", 
                                                        "paylocity_group_id"
                                                      ])
        end
      end
      context 'it should get departments group_field data' do        
        include_examples 'example succes status'
        it 'should return departments group_field key count and array with necessary keys ' do
          departments = @body['departments']
          expect(departments.first.count).to eq(10)
          expect(departments.first.keys).to eq([  "name",
                                                  "description",
                                                  "active",
                                                  "company_id",
                                                  "owner_id",
                                                  "users_count",
                                                  "adp_wfn_us_code_value",
                                                  "namely_group_type",
                                                  "namely_group_id",
                                                  "adp_wfn_can_code_value"
                                              ])
        end
      end
      context 'it should get departments group_field data' do       
        include_examples 'example succes status'
        it 'should return locations group_field key count and array with necessary keys ' do
          locations = @body['locations']
          expect(locations.first.count).to eq(11)
          expect(locations.first.keys).to eq([  "name",
                                                  "description",
                                                  "active",
                                                  "company_id",
                                                  "owner_id",
                                                  "users_count",
                                                  "adp_wfn_us_code_value",
                                                  "namely_group_type",
                                                  "namely_group_id",
                                                  "adp_wfn_can_code_value",
                                                  "is_gdpr_imposed"
                                              ])
        end
      end
    end
  end
end
