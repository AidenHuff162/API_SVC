require 'rails_helper'
RSpec.describe Api::V1::Admin::DocumentUploadRequestsController, type: :controller do

  let(:company) { create(:company) }
  let(:sarah) { create(:sarah, company: company) }
  let(:manager) { create(:nick, company:company) }
  let(:admin) { create(:peter, company:company) }
  let(:employee) { create(:tim, company:company) }
  let(:paperwork_packet) { create(:paperwork_packet, company: company)}

  let(:document_upload_request) { create(:request_with_connection_relation, company: company) }
  let(:document_upload_request1) { create(:request_with_connection_relation, company: company) }

  let!(:user_document_connection) { create(:user_document_connection, document_connection_relation: document_upload_request.document_connection_relation, company_id: company.id) }

  before do
    allow(controller).to receive(:current_user).and_return(sarah)
    allow(controller).to receive(:current_company).and_return(sarah.company)
  end

  describe "GET #index" do
    context 'should not get document upload requests' do
      context 'should not get document upload requests for unauthenticated user' do
        it 'should return 401 status' do
          allow(controller).to receive(:current_user).and_return(nil)

          get :index, format: :json
          expect(response.status).to eq(401)
        end
      end

      context "should not get document upload requests of other company" do
        let(:other_company) { create(:company, subdomain: 'faa') }
        let(:other_user) { create(:user, company: other_company) }

        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(other_user)

          get :index, format: :json
          expect(response.status).to eq(204)
        end
      end

      context "should not get document upload requests if user is employee" do
        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(employee)

          get :index, format: :json
          expect(response.status).to eq(204)
        end
      end

      context "should not get document upload requests if user is manager" do
        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(manager)

          get :index, format: :json
          expect(response.status).to eq(204)
        end
      end


      context "should get get document upload requests" do
        context "should get document upload requests if user is admin" do
          it 'should return OK status' do
            allow(controller).to receive(:current_user).and_return(admin)

            get :index, format: :json
            expect(response.status).to eq(200)
          end
        end

        context "should get document upload requests if user is super admin" do
          it 'should return OK status' do
            allow(controller).to receive(:current_user).and_return(sarah)

            get :index, format: :json
            expect(response.status).to eq(200)
          end
        end

        context "should get document upload requests" do
          before do
            get :index, format: :json
            @result = JSON.parse(response.body)
          end

          it "should return 200 status" do
            expect(response.status).to eq(200)
          end

          it "should return necessary keys count and necessary keys name of document upload requests" do
            expect(@result[0].keys.count).to eq(16)
            expect(@result[0].keys).to eq(["id", "title", "description", "global", "special_user_id", "company_id", "created_at", "position", "document_connection_relation_id", "meta", "locations", "departments", "status", "document_connection_relation", "special_user", "user"])
          end

          it "should return necessary keys count and necessary keys name of document connection relation" do
            expect(@result[0]['document_connection_relation'].keys.count).to eq(5)
            expect(@result[0]['document_connection_relation'].keys).to eq(["id", "title", "description", "doc_owners_count", "user_document_connections"])
          end

          it "should return necessary keys necessary keys name count of special user" do
            expect(@result[0]['special_user'].keys.count).to eq(18)
            expect(@result[0]['special_user'].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name", "preferred_full_name", "is_reset_password_token_set", "is_password_set", "about_you", "provider", "display_name_format", "title", "location_name", "seen_profile_setup", "seen_documents_v2", "ui_switcher", "picture", "profile_image"])
          end

          it "should return necessary keys necessary keys name count of user" do
            expect(@result[0]['user'].keys.count).to eq(18)
            expect(@result[0]['user'].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name", "preferred_full_name", "is_reset_password_token_set", "is_password_set", "about_you", "provider", "display_name_format", "title", "location_name", "seen_profile_setup", "seen_documents_v2", "ui_switcher", "picture", "profile_image"])
          end
        end
      end
    end
  end

  describe "GET #show" do
    context 'should not get document upload request' do
      context 'should not get document upload request for unauthenticated user' do
        it 'should return 401 status' do
          allow(controller).to receive(:current_user).and_return(nil)

          get :show, params: { id: document_upload_request.id }, format: :json
          expect(response.status).to eq(401)
        end
      end

      context "should not get document upload request of other company" do
        let(:other_company) { create(:company, subdomain: 'faa') }
        let(:other_user) { create(:user, company: other_company) }

        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(other_user)

          get :show, params: { id: document_upload_request.id }, format: :json
          expect(response.status).to eq(204)
        end
      end

      context "should not get document upload request if user is employee" do
        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(employee)

          get :show, params: { id: document_upload_request.id }, format: :json
          expect(response.status).to eq(204)
        end
      end

      context "should not get document upload request if user is manager" do
        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(manager)

          get :show, params: { id: document_upload_request.id }, format: :json
          expect(response.status).to eq(204)
        end
      end


      context "should get get document upload request" do
        context "should get document upload request if user is admin" do
          it 'should return OK status' do
            allow(controller).to receive(:current_user).and_return(admin)

            get :show, params: { id: document_upload_request.id }, format: :json
            expect(response.status).to eq(200)
          end
        end

        context "should get document upload request if user is super admin" do
          it 'should return OK status' do
            allow(controller).to receive(:current_user).and_return(sarah)

            get :show, params: { id: document_upload_request.id }, format: :json
            expect(response.status).to eq(200)
          end
        end

        context "should get document upload request" do
          before do
            get :show, params: { id: document_upload_request.id }, format: :json
            @result = JSON.parse(response.body)
          end

          it "should return 200 status" do
            expect(response.status).to eq(200)
          end

          it "should return necessary keys count and necessary keys name of document upload requests" do
            expect(@result.keys.count).to eq(16)
            expect(@result.keys).to eq(["id", "title", "description", "global", "special_user_id", "company_id", "created_at", "position", "document_connection_relation_id", "meta", "locations", "departments", "status","document_connection_relation", "special_user", "user"])
          end

          it "should return necessary keys count and necessary keys name of document connection relation" do
            expect(@result['document_connection_relation'].keys.count).to eq(5)
            expect(@result['document_connection_relation'].keys).to eq(["id", "title", "description", "doc_owners_count", "user_document_connections"])
          end

          it "should return necessary keys necessary keys name count of special user" do
            expect(@result['special_user'].keys.count).to eq(17)
            expect(@result['special_user'].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name", "preferred_full_name", "is_reset_password_token_set", "is_password_set", "about_you", "provider", "display_name_format", "title", "location_name", "seen_profile_setup", "seen_documents_v2", "ui_switcher", "picture"])
          end

          it "should return necessary keys necessary keys name count of user" do
            expect(@result['user'].keys.count).to eq(17)
            expect(@result['user'].keys).to eq(["id", "first_name", "last_name", "full_name", "preferred_name", "preferred_full_name", "is_reset_password_token_set", "is_password_set", "about_you", "provider", "display_name_format", "title", "location_name", "seen_profile_setup", "seen_documents_v2", "ui_switcher", "picture"])
          end
        end
      end
    end
  end

  describe "GET #index" do
    context 'should not get document upload requests' do
      context 'should not get document upload requests for unauthenticated user' do
        it 'should return 401 status' do
          allow(controller).to receive(:current_user).and_return(nil)

          get :simple_index, format: :json
          expect(response.status).to eq(401)
        end
      end

      context "should not get document upload requests of other company" do
        let(:other_company) { create(:company, subdomain: 'faa') }
        let(:other_user) { create(:user, company: other_company) }

        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(other_user)

          get :simple_index, format: :json
          expect(response.status).to eq(204)
        end
      end

      context "should get get document upload requests" do

        context "should get document upload requests if user is employee" do
          it 'should return no content status' do
            allow(controller).to receive(:current_user).and_return(employee)

            get :simple_index, format: :json
            expect(response.status).to eq(200)
          end
        end

        context "should get document upload requests if user is manager" do
          it 'should return no content status' do
            allow(controller).to receive(:current_user).and_return(manager)

            get :simple_index, format: :json
            expect(response.status).to eq(200)
          end
        end

        context "should get document upload requests if user is admin" do
          it 'should return OK status' do
            allow(controller).to receive(:current_user).and_return(admin)

            get :simple_index, format: :json
            expect(response.status).to eq(200)
          end
        end

        context "should get document upload requests if user is super admin" do
          it 'should return OK status' do
            allow(controller).to receive(:current_user).and_return(sarah)

            get :simple_index, format: :json
            expect(response.status).to eq(200)
          end
        end

        context "should get document upload requests" do
          before do
            get :simple_index, format: :json
            @result = JSON.parse(response.body)
          end

          it "should return 200 status" do
            expect(response.status).to eq(200)
          end

          it "should return necessary keys count and necessary keys name of document upload requests" do
            expect(@result[0].keys.count).to eq(5)
            expect(@result[0].keys).to eq(["id", "title", "global", "position", "document_connection_relation"])
          end

          it "should return necessary keys count and necessary keys name of document connection relation" do
            expect(@result[0]['document_connection_relation'].keys.count).to eq(7)
            expect(@result[0]['document_connection_relation'].keys).to eq(["id", "title", "description", "deleted_at", "created_at", "updated_at", "env_migration"])
          end
        end
      end
    end
  end

  describe "GET #paginated_index" do

    context "should not return document upload requests" do

      context "should not return document upload requests of other company" do
        let(:other_company) { create(:company, subdomain: 'baoo') }
        let(:other_user) { create(:user, company: other_company) }

        it "should return no content status" do
          allow(controller).to receive(:current_user).and_return(other_user)

          params = {"draw"=>"1", "columns"=>{
            "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
            "1"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
            "2"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
            "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}}},
            "order"=>{"0"=>{"column"=>"1", "dir"=>"asc"}}, "start"=>"0", "length"=>"10", "search"=>{"value"=>"", "regex"=>"false"}, "format"=>"json"
          }

          get :paginated_index, params: params
          expect(response.status).to eq(204)
        end
      end

      context "should not return document upload requests for unauthenticated user" do
        it "should return unauthorized status" do
          allow(controller).to receive(:current_user).and_return(nil)

          params = {"draw"=>"1", "columns"=>{
            "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
            "1"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
            "2"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
            "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}}},
            "order"=>{"0"=>{"column"=>"1", "dir"=>"asc"}}, "start"=>"0", "length"=>"10", "search"=>{"value"=>"", "regex"=>"false"}, "format"=>"json"
          }

          get :paginated_index, params: params
          expect(response.status).to eq(401)
        end
      end
    end

    context "should return document upload requests" do
      before do
        14.times do |count|
          create(:request_with_connection_relation, company: company)
        end
        4.times do |count|
          @document_upload_request = create(:request_with_connection_relation, company: company)
          create(:user_document_connection, document_connection_relation: @document_upload_request.document_connection_relation, company_id: company.id)
        end
      end

      it "should return first page of document upload requests per page 10" do
        params = {"draw"=>"1", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"1", "dir"=>"asc"}}, "start"=>"0", "length"=>"10", "search"=>{"value"=>"", "regex"=>"false"}, "format"=>"json"}

        get :paginated_index, params: params

        data = JSON.parse(response.body)['data']
        expect(data.count).to eq(10)
      end

      it "should return third page of document upload requests per page 10" do
        params = {"draw"=>"1", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"1", "dir"=>"asc"}}, "start"=>"10", "length"=>"10", "search"=>{"value"=>"", "regex"=>"false"}, "format"=>"json"}

        get :paginated_index, params: params

        data = JSON.parse(response.body)['data']
        expect(data.count).to eq(9)
      end

      it "should return paginated document upload requests per page 15" do
        params = {"draw"=>"1", "columns"=>{
          "0"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "1"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}},
          "2"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}},
          "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}}},
          "order"=>{"0"=>{"column"=>"1", "dir"=>"asc"}}, "start"=>"0", "length"=>"15", "search"=>{"value"=>"", "regex"=>"false"}, "format"=>"json"}

        get :paginated_index, params: params

        data = JSON.parse(response.body)['data']
        expect(data.count).to eq(15)
      end
    end
  end

  describe "POST #create" do
    context 'should not create document upload requests' do
      context 'should not create document upload requests for unauthenticated user' do
        it 'should return 401 status' do
          allow(controller).to receive(:current_user).and_return(nil)
          post :create, params: { global: true, user_id: sarah.id, document_connection_relation: {title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json
          expect(response.status).to eq(401)
        end

        it 'should not create history' do
          allow(controller).to receive(:current_user).and_return(nil)
          expect{post :create, params: { global: true, user_id: sarah.id, document_connection_relation: {title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json}.to change{History.count}.by (0)
        end
      end

      context "should not create document upload requests of other company" do
        let(:other_company) { create(:company, subdomain: 'faa') }
        let(:other_user) { create(:user, company: other_company) }

        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(other_user)
          post :create, params: { global: true, user_id: sarah.id, document_connection_relation: {title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json
          expect(response.status).to eq(204)
        end

        it 'should not create history' do
          allow(controller).to receive(:current_user).and_return(other_user)
          expect{post :create, params: { global: true, user_id: sarah.id, document_connection_relation: {title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json}.to change{History.count}.by (0)
        end
      end
    end

    context 'should create document upload requests' do
      context "should create document upload request if user is employee" do
        it 'should return Created status' do
          allow(controller).to receive(:current_user).and_return(employee)
          post :create, params: { global: true, user_id: sarah.id, document_connection_relation: {title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, as: :json
          expect(response.status).to eq(201)
        end

        it 'should create history' do
          allow(controller).to receive(:current_user).and_return(employee)
          expect{post :create, params: { global: true, user_id: sarah.id, document_connection_relation: {title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, as: :json}.to change{History.count}.by (1)
        end
      end

      context "should create document upload request if user is manager" do
        it 'should return Created status' do
          allow(controller).to receive(:current_user).and_return(manager)
          post :create, params: { global: true, user_id: sarah.id, document_connection_relation: {title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, as: :json
          expect(response.status).to eq(201)
        end

        it 'should create history' do
          allow(controller).to receive(:current_user).and_return(manager)
          expect{post :create, params: { global: true, user_id: sarah.id, document_connection_relation: {title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, as: :json}.to change{History.count}.by (1)
        end
      end

      context "should create document upload request if user is admin" do
        it 'should return created status' do
          allow(controller).to receive(:current_user).and_return(admin)
          post :create, params: { global: true, user_id: sarah.id, document_connection_relation: {title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, as: :json
          expect(response.message).to eq('Created')
        end

        it 'should create history' do
          allow(controller).to receive(:current_user).and_return(admin)
          expect{post :create, params: { global: true, user_id: sarah.id, document_connection_relation: {title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, as: :json}.to change{History.count}.by (1)
        end
      end

      context "should create document upload request if user is super admin" do
        it 'should return Created status' do
          allow(controller).to receive(:current_user).and_return(sarah)
          post :create, params: { global: true, user_id: sarah.id, document_connection_relation: {title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, as: :json
          expect(response.message).to eq('Created')
        end

        it 'should create history' do
          allow(controller).to receive(:current_user).and_return(sarah)
          expect{post :create, params: { global: true, user_id: sarah.id, document_connection_relation: {title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, as: :json}.to change{History.count}.by (1)
        end
      end

      context 'should create document upload requests' do
        it "should create document upload request along document connection relation" do
          post :create, params: { global: true, user_id: sarah.id, document_connection_relation: {title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, as: :json
          expect(response.message).to eq('Created')
          expect(JSON.parse(response.body)["document_connection_relation"]).not_to be_nil
        end

        it 'should create history' do
          expect{post :create, params: { global: true, user_id: sarah.id, document_connection_relation: {title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, as: :json}.to change{History.count}.by (1)
        end
      end
    end
  end

  describe "PUT #update" do
   context 'should not update document upload requests' do
      context 'should not update document upload requests for unauthenticated user' do
        it 'should return 401 status' do
          allow(controller).to receive(:current_user).and_return(nil)
          put :update, params: { id: document_upload_request.id, document_connection_relation: {id: document_upload_request.document_connection_relation, title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json
          expect(response.status).to eq(401)
        end

        it 'should not create history' do
          allow(controller).to receive(:current_user).and_return(nil)
          expect{put :update, params: { id: document_upload_request.id, document_connection_relation: {id: document_upload_request.document_connection_relation, title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json}.to change{History.count}.by (0)
        end
      end

      context "should not update document upload requests of other company" do
        let(:other_company) { create(:company, subdomain: 'faa') }
        let(:other_user) { create(:user, company: other_company) }

        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(other_user)
          put :update, params: { id: document_upload_request.id, document_connection_relation: {id: document_upload_request.document_connection_relation, title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json
          expect(response.status).to eq(204)
        end

        it 'should not create history' do
          allow(controller).to receive(:current_user).and_return(other_user)
          expect{put :update, params: { id: document_upload_request.id, document_connection_relation: {id: document_upload_request.document_connection_relation, title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json}.to change{History.count}.by (0)
        end
      end

      context "should not update document upload request if user is employee" do
        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(employee)
          put :update, params: { id: document_upload_request.id, document_connection_relation: {id: document_upload_request.document_connection_relation, title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json
          expect(response.status).to eq(204)
        end

        it 'should not create history' do
          allow(controller).to receive(:current_user).and_return(employee)
          expect{put :update, params: { id: document_upload_request.id, document_connection_relation: {id: document_upload_request.document_connection_relation, title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json}.to change{History.count}.by (0)
        end
      end

      context "should not update document upload request if user is manager" do
        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(manager)
          put :update, params: { id: document_upload_request.id, document_connection_relation: {id: document_upload_request.document_connection_relation, title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json
          expect(response.status).to eq(204)
        end

        it 'should not create history' do
          allow(controller).to receive(:current_user).and_return(manager)
          expect{put :update, params: { id: document_upload_request.id, document_connection_relation: {id: document_upload_request.document_connection_relation, title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json}.to change{History.count}.by (0)
        end
      end
    end

    context 'should update document upload requests' do
      context "should update document upload request if user is admin" do
        it 'should return OK status' do
          allow(controller).to receive(:current_user).and_return(admin)
          put :update, params: { id: document_upload_request.id, document_connection_relation: {id: document_upload_request.document_connection_relation, title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json
          expect(response.status).to eq(200)
        end

        it 'should create history' do
          allow(controller).to receive(:current_user).and_return(admin)
          expect{put :update, params: { id: document_upload_request.id, document_connection_relation: {id: document_upload_request.document_connection_relation, title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json}.to change{History.count}.by (1)
        end
      end

      context "should update document upload request if user is super admin" do
        it 'should return OK status' do
          allow(controller).to receive(:current_user).and_return(sarah)
          put :update, params: { id: document_upload_request.id, document_connection_relation: {id: document_upload_request.document_connection_relation, title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json
          expect(response.status).to eq(200)
        end

        it 'should create history' do
          allow(controller).to receive(:current_user).and_return(sarah)
          expect{put :update, params: { id: document_upload_request.id, document_connection_relation: {id: document_upload_request.document_connection_relation, title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json}.to change{History.count}.by (1)
        end
      end

      context 'should update document upload requests' do
        it "should update document upload request along document connection relation" do
          put :update, params: { id: document_upload_request.id, document_connection_relation: {id: document_upload_request.document_connection_relation, title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json
          expect(response.message).to eq('OK')
        end

        it 'should create history' do
          expect{put :update, params: { id: document_upload_request.id, document_connection_relation: {id: document_upload_request.document_connection_relation, title: Faker::Hipster.word, description: Faker::Hipster.sentence} }, format: :json}.to change{History.count}.by (1)
        end
      end
    end
  end

  describe "DELETE #destroy" do
   context 'should not delete document upload requests' do
      context 'should not delete document upload requests for unauthenticated user' do
        it 'should return 401 status' do
          allow(controller).to receive(:current_user).and_return(nil)
          delete :destroy, params: { id: document_upload_request.id }, format: :json
          expect(response.status).to eq(401)
          expect(DocumentUploadRequest.count).to eq(1)
        end

        it 'should not create history' do
          allow(controller).to receive(:current_user).and_return(nil)
          expect{delete :destroy, params: { id: document_upload_request.id }, format: :json}.to change{History.count}.by (0)
        end
      end

      context "should not delete document upload requests of other company" do
        let(:other_company) { create(:company, subdomain: 'faa') }
        let(:other_user) { create(:user, company: other_company) }

        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(other_user)
          delete :destroy, params: { id: document_upload_request.id }, format: :json
          expect(response.status).to eq(204)
          expect(DocumentUploadRequest.count).to eq(1)
        end

        it 'should not create history' do
          allow(controller).to receive(:current_user).and_return(other_user)
          expect{delete :destroy, params: { id: document_upload_request.id }, format: :json}.to change{History.count}.by (0)
        end
      end

      context "should not delete document upload request if user is employee" do
        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(employee)
          delete :destroy, params: { id: document_upload_request.id }, format: :json
          expect(response.status).to eq(204)
          expect(DocumentUploadRequest.count).to eq(1)
        end

        it 'should not create history' do
          allow(controller).to receive(:current_user).and_return(employee)
          expect{delete :destroy, params: { id: document_upload_request.id }, format: :json}.to change{History.count}.by (0)
        end
      end

      context "should not delete document upload request if user is manager" do
        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(manager)
          delete :destroy, params: { id: document_upload_request.id }, format: :json
          expect(response.status).to eq(204)
          expect(DocumentUploadRequest.count).to eq(1)
        end

        it 'should not create history' do
          allow(controller).to receive(:current_user).and_return(manager)
          expect{delete :destroy, params: { id: document_upload_request.id }, format: :json}.to change{History.count}.by (0)
        end
      end
    end

    context 'should delete document upload requests' do
      context "should delete document upload request if user is admin" do
        it 'should return no context status' do
          allow(controller).to receive(:current_user).and_return(admin)
          delete :destroy, params: { id: document_upload_request.id }, format: :json
          expect(response.status).to eq(204)
          expect(DocumentUploadRequest.count).to eq(0)
        end

        it 'should create history' do
          allow(controller).to receive(:current_user).and_return(admin)
          expect{delete :destroy, params: { id: document_upload_request.id }, format: :json}.to change{History.count}.by (1)
        end
      end

      context "should delete document upload request if user is super admin" do
        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(sarah)
          delete :destroy, params: { id: document_upload_request.id }, format: :json
          expect(response.status).to eq(204)
          expect(DocumentUploadRequest.count).to eq(0)
        end

        it 'should create history' do
          allow(controller).to receive(:current_user).and_return(sarah)
          expect{delete :destroy, params: { id: document_upload_request.id }, format: :json}.to change{History.count}.by (1)
        end
      end

      context 'should delete document upload requests' do
        it "should delete document upload request along document connection relation" do
          delete :destroy, params: { id: document_upload_request.id }, format: :json
          expect(response.status).to eq(204)
          expect(DocumentUploadRequest.count).to eq(0)
        end

        it 'should create history' do
          expect{delete :destroy, params: { id: document_upload_request.id }, format: :json}.to change{History.count}.by (1)
        end
      end
    end
  end

  describe "POST #bulk_assign_upload_request" do
    context 'should not bulk assign document upload requests' do
      context 'should not bulk assign document upload requests for unauthenticated user' do
        it 'should return 401 status' do
          allow(controller).to receive(:current_user).and_return(nil)

          put :bulk_assign_upload_requests, params: { user_id: employee.id, upload_request_ids: [1,2,3], packet_id: paperwork_packet.id }, format: :json
          expect(response.status).to eq(401)
        end
      end

      context "should not bulk assign document upload requests of other company" do
        let(:other_company) { create(:company, subdomain: 'faa') }
        let(:other_user) { create(:user, company: other_company) }

        it 'should return no content status' do
          allow(controller).to receive(:current_user).and_return(other_user)

          put :bulk_assign_upload_requests, params: { user_id: employee.id, upload_request_ids: [1,2,3], packet_id: paperwork_packet.id }, format: :json
          expect(response.status).to eq(204)
        end
      end
    end

    context 'should bulk assign document upload requests' do
      before do
        @encrypted_token = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base).encrypt_and_sign(SecureRandom.uuid + "-" + DateTime.now.to_s)
      end

      context "should bulk assign document upload request if user is employee" do
        it 'should return OK status' do
          allow(controller).to receive(:current_user).and_return(employee)

          put :bulk_assign_upload_requests, params: { user_id: employee.id, upload_request_ids: [1,2,3], packet_id: paperwork_packet.id, document_token: @encrypted_token }, format: :json
          expect(response.status).to eq(200)
        end
      end

      context "should not bulk assign document upload request if user is manager" do
        it 'should return OK status' do
          allow(controller).to receive(:current_user).and_return(manager)

          put :bulk_assign_upload_requests, params: { user_id: employee.id, upload_request_ids: [1,2,3], packet_id: paperwork_packet.id, document_token: @encrypted_token }, format: :json
          expect(response.status).to eq(200)
        end
      end

      context "should bulk assign document upload request if user is admin" do
        it 'should return OK status' do
          allow(controller).to receive(:current_user).and_return(admin)

          put :bulk_assign_upload_requests, params: { user_id: employee.id, upload_request_ids: [document_upload_request.id, document_upload_request1.id], packet_id: paperwork_packet.id, document_token: @encrypted_token }, format: :json
          expect(response.status).to eq(200)
        end
      end

      context "should bulk assign document upload request if user is super admin" do
        it 'should return OK status' do
          allow(controller).to receive(:current_user).and_return(sarah)

          put :bulk_assign_upload_requests, params: { user_id: employee.id, upload_request_ids: [document_upload_request.id, document_upload_request1.id], packet_id: paperwork_packet.id, document_token: @encrypted_token }, format: :json
          expect(response.status).to eq(200)
        end
      end

      context 'should bulk assign document upload requests' do
        it "should update document upload request along document connection relation" do

          expect { put :bulk_assign_upload_requests, params: { user_id: employee.id, upload_request_ids: [document_upload_request.id, document_upload_request1.id], packet_id: paperwork_packet.id, document_token: @encrypted_token }, format: :json }.to change { UserDocumentConnection.count }.by(2)
          expect(response.message).to eq('OK')
        end
      end
    end
  end

  describe "POST #duplicate" do
    it 'should duplicate upload document request' do
      post :duplicate, params: { id: document_upload_request.id }, format: :json
      expect(response.status).to eq(201)
    end

    it 'should create history for duplicate upload document request' do
      expect{post :duplicate, params: { id: document_upload_request.id }, format: :json}.to change{History.count}.by (1)
    end
  end
end
