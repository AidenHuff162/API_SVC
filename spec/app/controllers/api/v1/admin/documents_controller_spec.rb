require 'rails_helper'
# require "cancan/matchers"

RSpec.describe Api::V1::Admin::DocumentsController, type: :controller do
  let(:company) { create(:company, subdomain: 'document') }
  let(:sarah) { create(:sarah, company: company) }
  let(:manager) { create(:nick, company: company) }
  let!(:employee) { create(:tim, manager: manager, company: company) }
  let(:admin) { create(:peter, company: company) }
  let!(:attachment) {create(:document_file) }
  let(:document) { create(:document, company: company) }

  before do
    allow(controller).to receive(:current_user).and_return(sarah)
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe 'get #index' do
    let!(:document) { create(:document, company: company) }
    context 'should not get documents' do
      context 'if current_user is not present' do
        it 'should return Unauthorized status' do
          allow(controller).to receive(:current_user).and_return(nil)
          get :index, format: :json
          expect(response.status).to eq(401)
          expect(response.message).to eq('Unauthorized')
        end
      end

      context 'if current_company is not present' do
        it 'should return Not found status ' do
          allow(controller).to receive(:current_company).and_return(nil)
          get :index, format: :json
          expect(response.status).to eq(404)
          expect(response.message).to eq('Not Found')
        end
      end

      context 'if current_user is of other company' do
        let(:other_company) { create(:company, subdomain: 'other_document') }

        it 'should return Forbidden status ' do
          allow(controller).to receive(:current_company).and_return(other_company)
          get :index, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end

      context 'if current_user is employee' do
        it 'should return forbidden status ' do
          allow(controller).to receive(:current_user).and_return(employee)
          get :index, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end

       context 'if current_user is manager' do
        it 'should return forbidden status ' do
          allow(controller).to receive(:current_user).and_return(manager.reload)
          get :index, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end
    end

    context 'should get documents' do
      context 'if current_user is admin' do
        it 'should return Ok status' do
          allow(controller).to receive(:current_user).and_return(admin)
          get :index, format: :json
          expect(response.status).to eq(200)
          expect(response.message).to eq('OK')
        end
      end

      context 'if current_user is super admin' do
        it 'should return Ok status' do
          allow(controller).to receive(:current_user).and_return(sarah)
          get :index, format: :json
          expect(response.status).to eq(200)
          expect(response.message).to eq('OK')
        end
      end

      context 'if request is successful' do
        it 'should return 200 status and 4 keys of documents and valid keys of documents' do
          get :index, format: :json
          expect(JSON.parse(response.body).first.keys.count).to eq(8)
          expect(JSON.parse(response.body).first.keys).to eq(["id", "title", "description", "attached_file", "meta", "locations", "departments", "status"])
        end
      end
    end
  end

  describe 'post #create' do
    context 'should not create documents' do
      context 'if current_user is not present' do
        it 'should return Unauthorized status' do
          allow(controller).to receive(:current_user).and_return(nil)
          post :create, params: { title: 'title' }, format: :json
          expect(response.status).to eq(401)
          expect(response.message).to eq('Unauthorized')
        end
      end

      context 'if current_company is not present' do
        it 'should return Not found status ' do
          allow(controller).to receive(:current_company).and_return(nil)
          post :create, params: { title: 'title' }, format: :json
          expect(response.status).to eq(404)
          expect(response.message).to eq('Not Found')
        end
      end

      context 'if current_user is of other company' do
        let(:other_company) { create(:company, subdomain: 'other_document') }

        it 'should return Forbidden status ' do
          allow(controller).to receive(:current_company).and_return(other_company)
          post :create, params: { title: 'title' }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end
    end

    context 'should create documents' do
      context 'if current_user is admin' do
        it 'should return created status and increase document count' do
          allow(controller).to receive(:current_user).and_return(admin)
          post :create, params: { title: 'title', description: 'description', attached_file: attachment.attributes }, format: :json
          expect(response.status).to eq(201)
          expect(response.message).to eq('Created')
          expect(Document.count).to eq(1)
        end
      end

      context 'if current_user is super admin' do
        it 'should return created status and increase document count' do
          allow(controller).to receive(:current_user).and_return(sarah)
          post :create, params: { title: 'title', description: 'description', attached_file: attachment.attributes }, format: :json
          expect(response.status).to eq(201)
          expect(response.message).to eq('Created')
          expect(Document.count).to eq(1)
        end
      end
    end
  end

  describe 'delete #destroy' do
    context 'should not destroy documents' do
      context 'if current_user is not present' do
        it 'should return Unauthorized status' do
          allow(controller).to receive(:current_user).and_return(nil)
          delete :destroy, params: { id: document.id }, format: :json
          expect(response.status).to eq(401)
          expect(response.message).to eq('Unauthorized')
        end
      end

      context 'if current_company is not present' do
        it 'should return Not found status ' do
          allow(controller).to receive(:current_company).and_return(nil)
          delete :destroy, params: { id: document.id }, format: :json
          expect(response.status).to eq(404)
          expect(response.message).to eq('Not Found')
        end
      end

      context 'if current_user is of other company' do
        let(:other_company) { create(:company, subdomain: 'other_document') }

        it 'should return Forbidden status ' do
          allow(controller).to receive(:current_company).and_return(other_company)
          delete :destroy, params: { id: document.id }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end
    end

    context 'should destroy documents' do
      context 'if current_user is admin' do
        it 'should return No content status and decrease document count' do
          allow(controller).to receive(:current_user).and_return(admin)
          delete :destroy, params: { id: document.id }, format: :json
          expect(response.status).to eq(204)
          expect(response.message).to eq('No Content')
          expect(Document.count).to eq(0)
        end
      end

      context 'if current_user is super admin' do
        it 'should return No content status and decrease document count' do
          allow(controller).to receive(:current_user).and_return(sarah)
          delete :destroy, params: { id: document.id }, format: :json
          expect(response.status).to eq(204)
          expect(response.message).to eq('No Content')
          expect(Document.count).to eq(0)
        end
      end
    end
  end

  describe 'post #update' do
    context 'should not update document' do
      context 'if current_user is not present' do
        it 'should return Unauthorized status' do
          allow(controller).to receive(:current_user).and_return(nil)
          post :update, params: { id: document.id, title: 'title', description: 'description', attached_file: attachment.attributes }, format: :json
          expect(response.status).to eq(401)
          expect(response.message).to eq('Unauthorized')
        end

        it 'should not create history' do
          allow(controller).to receive(:current_user).and_return(nil)
          expect{post :update, params: { id: document.id, title: 'title', description: 'description', attached_file: attachment.attributes }, format: :json}.to change{History.count}.by (0)
        end
      end

      context 'if current_company is not present' do
        it 'should return Not found status ' do
          allow(controller).to receive(:current_company).and_return(nil)
          post :update, params: { id: document.id, title: 'title', description: 'description', attached_file: attachment.attributes }, format: :json
          expect(response.status).to eq(404)
          expect(response.message).to eq('Not Found')
        end

        it 'should not create history' do
          allow(controller).to receive(:current_user).and_return(nil)
          expect{post :update, params: { id: document.id, title: 'title', description: 'description', attached_file: attachment.attributes }, format: :json}.to change{History.count}.by (0)
        end
      end

      context 'if current_user is of other company' do
        let(:other_company) { create(:company, subdomain: 'other_document') }

        it 'should return Forbidden status ' do
          allow(controller).to receive(:current_company).and_return(other_company)
          post :update, params: { id: document.id, title: 'title', description: 'description', attached_file: attachment.attributes }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end

        it 'should not create history' do
          allow(controller).to receive(:current_company).and_return(other_company)
          expect{post :update, params: { id: document.id, title: 'title', description: 'description', attached_file: attachment.attributes }, format: :json}.to change{History.count}.by (0)
        end
      end
    end

    context 'should update documents' do
      context 'if current_user is admin' do
        it 'should return created status and document count is one' do
          allow(controller).to receive(:current_user).and_return(admin)
          post :update, params: { id: document.id, title: 'title', description: 'description', attached_file: attachment.attributes, meta: {} }, as: :json
          expect(response.status).to eq(201)
          expect(response.message).to eq('Created')
          expect(Document.count).to eq(1)
        end

        it 'should create history' do
          allow(controller).to receive(:current_user).and_return(admin)
          expect{post :update, params: { id: document.id, title: 'title', description: 'description', attached_file: attachment.attributes, meta: {} }, as: :json}.to change{History.count}.by (1)
        end
      end

      context 'if current_user is super admin' do
        it 'should return created status and document count is one' do
          allow(controller).to receive(:current_user).and_return(sarah)
          post :update, params: { id: document.id, title: 'title', description: 'description', attached_file: attachment.attributes, meta: {} },as: :json
          expect(response.status).to eq(201)
          expect(response.message).to eq('Created')
          expect(Document.count).to eq(1)
        end

        it 'should create history' do
          allow(controller).to receive(:current_user).and_return(sarah)
          expect{post :update, params: { id: document.id, title: 'title', description: 'description', attached_file: attachment.attributes, meta: {} },as: :json}.to change{History.count}.by (1)
        end
      end
    end
  end

  describe 'get #show' do
    context 'should not get document' do
      context 'if current_user is not present' do
        it 'should return Unauthorized status' do
          allow(controller).to receive(:current_user).and_return(nil)
          get :show, params: { id: document.id }, format: :json
          expect(response.status).to eq(401)
          expect(response.message).to eq('Unauthorized')
        end
      end

      context 'if current_company is not present' do
        it 'should return Not found status ' do
          allow(controller).to receive(:current_company).and_return(nil)
          get :show, params: { id: document.id }, format: :json
          expect(response.status).to eq(404)
          expect(response.message).to eq('Not Found')
        end
      end

      context 'if current_user is of other company' do
        let(:other_company) { create(:company, subdomain: 'other_document') }

        it 'should return Forbidden status ' do
          allow(controller).to receive(:current_company).and_return(other_company)
          get :show, params: { id: document.id }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end

      context 'if current_user is employee' do
        it 'should return forbidden status ' do
          allow(controller).to receive(:current_user).and_return(employee)
          get :show, params: { id: document.id }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end

       context 'if current_user is manager' do
        it 'should return forbidden status ' do
          allow(controller).to receive(:current_user).and_return(manager.reload)
          get :show, params: { id: document.id }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end
    end

    context 'should get document' do
      context 'if current_user is admin' do
        it 'should return Ok status' do
          allow(controller).to receive(:current_user).and_return(admin)
          get :show, params: { id: document.id }, format: :json
          expect(response.status).to eq(200)
          expect(response.message).to eq('OK')
        end
      end

      context 'if current_user is super admin' do
        it 'should return Ok status' do
          allow(controller).to receive(:current_user).and_return(sarah)
          get :show, params: { id: document.id }, format: :json
          expect(response.status).to eq(200)
          expect(response.message).to eq('OK')
        end
      end

      context 'if request is successful' do
        it 'should return 200 status and 4 keys of documents and valid keys of documents' do
          get :show, params: { id: document.id }, format: :json
          expect(JSON.parse(response.body).keys.count).to eq(8)
          expect(JSON.parse(response.body).keys).to eq(["id", "title", "description", "attached_file", "meta", "locations", "departments", "status"])
        end
      end
    end
  end
end
