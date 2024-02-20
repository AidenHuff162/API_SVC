require 'rails_helper'

RSpec.describe Api::V1::PersonalDocumentsController, type: :controller do

  let(:company) { create(:company_with_team_and_location, subdomain: 'personal-document-ctrl') }
  let(:sarah) { create(:sarah, company: company) }
  let(:peter) { create(:peter, company: company) }
  let(:nick) { create(:nick, company: company) }
  let(:tim) { create(:tim, company: company, manager: nick) }
  let(:indirect_employee) { create(:user, manager: tim, company: company) }
  let(:location) { create(:location, company: company) }
  let(:team) { create(:team, company: company) }

  let(:personal_document1) { create(:personal_document, user: tim, created_by_id: peter.id) }
  let(:personal_document2) { create(:personal_document, user: nick, created_by_id: peter.id) }
  let!(:personal_document_file) { create(:personal_document_file, entity_id: personal_document2.id, entity_type: 'PersonalDocument') }

  describe 'POST #create' do
    before do
      allow(controller).to receive(:current_company).and_return(company)
      allow(controller).to receive(:current_user).and_return(sarah)
    end

    context 'should not create document for unauthorized user' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        post :create, params: { user_id: tim.id, title: 'PD', description: 'Its a personal document' }, format: :json
      end

      it "should return unauthorized status" do
        expect(response.status).to eq(401)
      end

      it "should not create history" do
        expect(History.count).to eq(0)
      end
    end

    context 'should not create document for other company' do
      let(:other_company) { create(:company, subdomain: 'personal-document-ctrl2') }
      let(:other_user) { create(:user, company: other_company) }

      it 'should return forbidden status if user does not belong to current company' do
        post :create, params: { user_id: other_user.id, title: 'PD', description: 'Its a personal document' }, format: :json
        expect(response.status).to eq(403)
      end

      it 'should not create history if user does not belong to current company' do
        expect{post :create, params: { user_id: other_user.id, title: 'PD', description: 'Its a personal document' }, format: :json}.to change{History.count}.by (0)
      end

      it 'should return forbidden status if company does not belong to current user' do
        allow(controller).to receive(:current_user).and_return(other_user)
        post :create, params: { user_id: other_user.id, title: 'PD', description: 'Its a personal document' }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should not create history if company does not belong to current user' do
        expect{post :create, params: { user_id: other_user.id, title: 'PD', description: 'Its a personal document' }, format: :json}.to change{History.count}.by (0)
      end
    end

    context 'should create personal document' do
      it 'should return created status and create document in table' do
        post :create, params: { user_id: tim.id, title: 'PD', description: 'Its a personal document' }, format: :json
        expect(response.status).to eq(201)
        expect(PersonalDocument.where(user_id: tim.id).count).to eq(1)
      end

      it 'should create history' do
        expect{post :create, params: { user_id: tim.id, title: 'PD', description: 'Its a personal document' }, format: :json}.to change{History.count}.by (1)
      end
    end
  end

  describe 'PUT #update' do
    before do
      allow(controller).to receive(:current_company).and_return(company)
      allow(controller).to receive(:current_user).and_return(sarah)
    end

    context 'should not update document for unauthorized user' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        put :update, params: { id: personal_document1.id, title: 'PD-Update' }, format: :json
      end

      it "should return unauthorized status" do
        expect(response.status).to eq(401)
      end
    end

    context 'should not update document for other company' do
      let(:other_company) { create(:company, subdomain: 'personal-document-ctrl2') }
      let(:other_user) { create(:user, company: other_company) }
      let(:other_personal_document) { create(:personal_document, user: other_user, created_by_id: other_user.id) }

      it 'should return forbidden status if user does not belong to current company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        put :update, params: { id: other_personal_document.id, title: 'PD-Update', description: 'Its a personal document' }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return forbidden status if company does not belong to current user' do
        allow(controller).to receive(:current_user).and_return(other_user)
        put :update, params: { id: other_personal_document.id, title: 'PD-Update', description: 'Its a personal document' }, format: :json
        expect(response.status).to eq(204)
      end
    end

    context 'should update personal document' do
      it 'should return ok status and update document in table' do
        put :update, params: { id: personal_document1.id, title: 'PD-Update', description: 'Its a personal document' }, format: :json
        expect(response.status).to eq(200)
        expect(PersonalDocument.find(personal_document1.id).title).to eq('PD-Update')
      end
    end
  end

  describe 'DELETE #destroy' do
    before do
      allow(controller).to receive(:current_company).and_return(company)
      allow(controller).to receive(:current_user).and_return(sarah)
    end

    context 'should not delete document for unauthorized user' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        delete :destroy, params: { id: personal_document1.id }, format: :json
      end

      it "should return unauthorized status" do
        expect(response.status).to eq(401)
      end

      it 'should not create history' do
        expect(History.count).to eq(0)
      end
    end

    context 'should not delete document for other company' do
      let(:other_company) { create(:company, subdomain: 'personal-document-ctrl2') }
      let(:other_user) { create(:user, company: other_company) }
      let(:other_personal_document) { create(:personal_document, user: other_user, created_by_id: other_user.id) }

      it 'should return forbidden status if user does not belong to current company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        delete :destroy, params: { id: personal_document1.id }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should not create history if user does not belong to current company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect{delete :destroy, params: { id: personal_document1.id }, format: :json}.to change{History.count}.by (0)
      end

      it 'should return forbidden status if document belong to other company' do
        delete :destroy, params: { id: other_personal_document.id }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should not create history if document belong to other company' do
        expect{delete :destroy, params: { id: other_personal_document.id }, format: :json}.to change{History.count}.by (0)
      end

      it 'should return forbidden status if company does not belong to current user' do
        allow(controller).to receive(:current_user).and_return(other_user)
        delete :destroy, params: { id: personal_document1.id }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should not create history if company does not belong to current user' do
        allow(controller).to receive(:current_user).and_return(other_user)
        expect{delete :destroy, params: { id: personal_document1.id }, format: :json}.to change{History.count}.by (0)
      end
    end

    context 'should delete personal document' do
      it 'should return ok status and delete document in table' do
        delete :destroy, params: { id: personal_document1.id }, format: :json
        expect(response.status).to eq(204)
        expect(PersonalDocument.find_by_id(personal_document1.id)).to eq(nil)
      end

      it 'should create history' do
        expect{delete :destroy, params: { id: personal_document1.id }, format: :json}.to change{History.count}.by (1)
      end
    end
  end

  describe 'GET #index' do
    before do
      allow(controller).to receive(:current_company).and_return(company)
      allow(controller).to receive(:current_user).and_return(sarah)
    end

    context 'should not get documents for unauthorized user' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        get :index, params: { user_id: personal_document1.user_id }, format: :json
      end

      it "should return unauthorized status" do
        expect(response.status).to eq(401)
      end
    end

    context 'should not get documents for other company' do
      let(:other_company) { create(:company, subdomain: 'personal-document-ctrl2') }
      let(:other_user) { create(:user, company: other_company) }
      let(:other_personal_document) { create(:personal_document, user: other_user, created_by_id: other_user.id) }

      it 'should return forbidden status if user does not belong to current company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        get :index, params: { user_id: personal_document1.user_id }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return forbidden status if document belong to other company' do
        get :index, params: { user_id: other_personal_document.user_id }, format: :json
        expect(response.status).to eq(403)
      end

      it 'should return forbidden status if company does not belong to current user' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :index, params: { user_id: personal_document1.user_id }, format: :json
        expect(response.status).to eq(204)
      end
    end

    context 'should get documents' do
      let!(:other_company) { create(:company, subdomain: 'personal-document-ctrl2') }
      let!(:other_user) { create(:user, company: other_company) }
      let!(:other_personal_document) { create(:personal_document, user: other_user, created_by_id: other_user.id) }

      before do
        personal_document1
        personal_document2
      end

      it 'should return ok status and company based documents' do
        get :index, params: { company_id: company.id }, format: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body).count).to eq(2)
      end

      it 'should return ok status and user based documents' do
        get :index, params: { user_id: tim.id }, format: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body).count).to eq(1)
      end
    end

    context 'should manager get documents as per permissions' do
      before do
        personal_document1
        personal_document2
      end

      it 'should get documents if requester is super-admin' do
        get :index, params: { user_id: tim.id }, format: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body).count).to eq(1)
      end

      it 'should get documents if requester is admin and has platform visibility permission' do
        allow(controller).to receive(:current_user).and_return(peter)

        get :index, params: { user_id: tim.id }, format: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body).count).to eq(1)
      end

      it 'should get no content status if requester is admin and has not platform visibility permission' do
        allow(controller).to receive(:current_user).and_return(peter)

        permissions = peter.user_role.permissions
        permissions['platform_visibility']['document'] = 'no_access'
        peter.user_role.update_columns(permissions: permissions)

        get :index, params: { user_id: tim.id }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should get no content status if requester is admin and has platform visibility permission but different team permission level' do
        allow(controller).to receive(:current_user).and_return(peter)

        permissions = peter.user_role.permissions
        permissions['platform_visibility']['document'] = 'no_access'
        peter.user_role.update_columns(permissions: permissions, team_permission_level: [company.teams[0].id.to_s])
        tim.update_columns(team_id: company.teams[1].id)

        get :index, params: { user_id: tim.id }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should get no content status if requester is admin and has platform visibility permission but different location permission level' do
        allow(controller).to receive(:current_user).and_return(peter)

        permissions = peter.user_role.permissions
        permissions['platform_visibility']['document'] = 'no_access'
        peter.user_role.update_columns(permissions: permissions, location_permission_level: [company.locations[0].id.to_s])
        tim.update_columns(location_id: company.locations[1].id)

        get :index, params: { user_id: tim.id }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should get documents if requester is admin and has platform visibility permission and same location/team permission level' do
        allow(controller).to receive(:current_user).and_return(peter)

        permissions = peter.user_role.permissions
        permissions['platform_visibility']['document'] = 'view_and_edit'
        peter.user_role.update_columns(permissions: permissions, team_permission_level: [company.teams[0].id.to_s], location_permission_level: [company.locations[0].id.to_s])
        tim.update_columns(location_id: company.locations[0].id, team_id: company.teams[0].id)

        get :index, params: { user_id: tim.id }, format: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body).count).to eq(1)
      end

      it 'should get documents if requester is user and has platform visibility' do
        allow(controller).to receive(:current_user).and_return(tim)

        get :index, params: { user_id: tim.id }, format: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body).count).to eq(1)
      end

      it 'should not get documents if requester is user and has no platform visibility' do
        allow(controller).to receive(:current_user).and_return(tim)

        permissions = tim.user_role.permissions
        permissions['platform_visibility']['document'] = 'no_access'
        tim.user_role.update_columns(permissions: permissions)

        get :index, params: { user_id: tim.id }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should not get documents if requester is user and has platform visibility but want to access any other users data' do
        allow(controller).to receive(:current_user).and_return(tim)

        get :index, params: { user_id: nick.id }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should not get documents if requester is user and has no platform visibility but manager of other user' do
        allow(controller).to receive(:current_user).and_return(nick)
        nick.update_columns(user_role_id: company.user_roles.find_by(name: 'Manager').id)

        get :index, params: { user_id: tim.id }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should get documents if requester is user and has platform visibility but manager of other user' do
        allow(controller).to receive(:current_user).and_return(nick)
        nick.update_columns(user_role_id: company.user_roles.find_by(name: 'Manager').id)

        permissions = nick.user_role.permissions
        permissions['platform_visibility']['document'] = 'view_and_edit'
        nick.user_role.update_columns(permissions: permissions)

        get :index, params: { user_id: tim.id }, format: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body).count).to eq(1)
      end

      it 'should get documents if requester is user and has platform visibility but manager of other user indirectly' do
        allow(controller).to receive(:current_user).and_return(nick)
        nick.update_columns(user_role_id: company.user_roles.find_by(name: 'Manager').id)

        permissions = nick.user_role.permissions
        permissions['platform_visibility']['document'] = 'view_and_edit'
        nick.user_role.update_columns(permissions: permissions)

        get :index, params: { user_id: indirect_employee.id }, format: :json
        expect(response.status).to eq(200)
      end

      it 'should not get documents if requester is user and has platform visibility but manager of other user directly' do
        allow(controller).to receive(:current_user).and_return(nick)
        nick.update_columns(user_role_id: company.user_roles.find_by(name: 'Manager').id)

        permissions = nick.user_role.permissions
        permissions['platform_visibility']['document'] = 'view_and_edit'
        nick.user_role.update_columns(permissions: permissions, reporting_level: 0)

        get :index, params: { user_id: indirect_employee.id }, format: :json
        expect(response.status).to eq(204)
      end
    end
  end

  describe 'GET #download_url' do
    before do
      allow(controller).to receive(:current_company).and_return(company)
      allow(controller).to receive(:current_user).and_return(sarah)
    end

    context 'should not get download url for unauthorized user' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        get :download_url, params: { id: personal_document1.id }, format: :json
      end

      it "should return unauthorized status" do
        expect(response.status).to eq(401)
      end
    end

    context 'should not get download url for other company' do
      let(:other_company) { create(:company, subdomain: 'personal-document-ctrl2') }
      let(:other_user) { create(:user, company: other_company) }
      let(:other_personal_document) { create(:personal_document, user: other_user, created_by_id: other_user.id) }

      it 'should return forbidden status if user does not belong to current company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        get :download_url, params: { id: other_personal_document.id }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return forbidden status if company does not belong to current user' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :download_url, params: { id: other_personal_document.id }, format: :json
        expect(response.status).to eq(204)
      end
    end
  end

  describe 'GET #download_url' do
    before do
      allow(controller).to receive(:current_company).and_return(company)
      allow(controller).to receive(:current_user).and_return(sarah)
    end

    context 'should download_url' do
      it "should return 200 status" do
        get :download_url, params: { id: personal_document2.id }, format: :json
        expect(response.status).to eq(200)
      end
    end
  end
end