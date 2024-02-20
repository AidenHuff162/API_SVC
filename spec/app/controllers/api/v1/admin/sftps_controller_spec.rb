require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe Api::V1::Admin::SftpsController, type: :controller do
  let(:company) { create(:company) }
  let(:super_admin) { create(:sarah, company: company) }
  let!(:sftp) { create(:sftp, updated_by_id: super_admin.id, company: company) }
  let(:admin) { create(:peter, company: company) }
  let(:manager) { create(:nick, company: company) }
  let(:employee) { create(:tim, company: company) }


  before do
    allow(controller).to receive(:current_company).and_return(company)
    allow(controller).to receive(:current_user).and_return(super_admin)
    allow(controller).to receive(:current_user).and_return(admin)
    role = admin.user_role
    role.permissions['admin_visibility']['integrations'] = 'view_and_edit'
    role.save!
    company.stub(:sftp_feature_flag) { true }
  end

  describe 'get #paginted' do
    context 'should not return sftps' do
      it 'should return unauthorised status for unauthenticated user' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :paginated, format: :json
        expect(response.status).to eq(401)
      end
      it 'should return forbidden status if current_company is nil' do
        allow(controller).to receive(:current_company).and_return(nil)
        get :paginated, format: :json
        
        expect(response.status).to eq(404)
      end
    end

    context 'should return sftps' do
      it 'should return 200 status and 4 sftp keys and valid keys sftp request' do
        get :paginated, params: { start: 0, length: 3 }, format: :json
        result = JSON.parse(response.body)
        expect(response.status).to eq(200)
        expect(result['data'][0].keys.count).to eq(5)
        expect(result['data'][0].keys).to eq(['id', 'name', 'host_url', 'updater_full_name', 'updated_at'])
      end
    end
  end

  describe 'post #create' do
    context 'should not create sftp' do
      context 'if current_user is not present' do
        it 'should return Unauthorized status' do
          allow(controller).to receive(:current_user).and_return(nil)
          post :create, params: { name: 'name' }, format: :json
          expect(response.status).to eq(401)
          expect(response.message).to eq('Unauthorized')
        end
      end

      context 'if current_company is not present' do
        it 'should return Not found status ' do
          allow(controller).to receive(:current_company).and_return(nil)
          post :create, params: { name: 'name' }, format: :json
          expect(response.status).to eq(404)
          expect(response.message).to eq('Not Found')
        end
      end

      context 'if current_user is employee' do
        it 'should return forbidden status ' do
          allow(controller).to receive(:current_user).and_return(employee)
          post :create, params: { name: 'name' }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end

      context 'if current_user is manager' do
        it 'should return forbidden status ' do
          allow(controller).to receive(:current_user).and_return(manager)
          post :create, params: { name: 'name' }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end

      context 'if current_user is of other company' do
        let(:other_company) { create(:company, subdomain: 'other_sftp') }

        it 'should return Forbidden status ' do
          allow(controller).to receive(:current_company).and_return(other_company)
          post :create, params: { name: 'name' }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end

      context 'if required params are missing' do
        it 'should return not create sftp while User name is missing ' do
          allow(controller).to receive(:current_user).and_return(admin)
          allow(controller).to receive(:current_company).and_return(company)
          post :create, params: { name: 'name', host_url: 'hosturl', authentication_key_type: 'credentials', encrypted_password: 'password', port: 8080, folder_path: 'folderpath', updated_by_id: admin.id, company_id: company.id }, format: :json
          json = JSON.parse(response.body)
          expect(json["errors"][0]["details"]).to eq("Validation failed")
          expect(json["errors"][0]["messages"]).to include("User name can't be blank")
        end
      end
    end

    context 'should create sftp' do
      context 'if current_user is admin' do
        it 'should return created status and increase sftp count' do
          allow(controller).to receive(:current_user).and_return(admin)
          allow(controller).to receive(:current_company).and_return(company)
          post :create, params: { name: 'name', host_url: 'hosturl', authentication_key_type: 'credentials', user_name: 'username' ,encrypted_password: 'password', port: 8080, folder_path: 'folderpath', updated_by_id: admin.id, company_id: company.id }, format: :json
          expect(response.status).to eq(201)
          expect(response.message).to eq('Created')
          expect(Sftp.count).to eq(2)
        end
      end

      context 'if current_user is super admin' do
        it 'should return created status and increase sftp count' do
          allow(controller).to receive(:current_user).and_return(super_admin)
          post :create, params: { name: 'name', host_url: 'hosturl', authentication_key_type: 'credentials', port: 8080, user_name: 'username', updated_by_id: super_admin.id ,encrypted_password: 'password', folder_path: 'folderpath', company_id: company.id }, format: :json
          expect(response.status).to eq(201)
          expect(response.message).to eq('Created')
          expect(Sftp.count).to eq(2)
        end
      end
    end
  end

  describe 'delete #destroy' do
    context 'should not destroy Sftp' do
      context 'if current_user is not present' do
        it 'should return Unauthorized status' do
          allow(controller).to receive(:current_user).and_return(nil)
          delete :destroy, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(401)
          expect(response.message).to eq('Unauthorized')
        end
      end

      context 'if current_company is not present' do
        it 'should return Not found status ' do
          allow(controller).to receive(:current_company).and_return(nil)
          delete :destroy, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(404)
          expect(response.message).to eq('Not Found')
        end
      end

      context 'if current_user is employee' do
        it 'should return forbidden status ' do
          allow(controller).to receive(:current_user).and_return(employee)
          delete :destroy, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end

      context 'if current_user is of other company' do
        let(:other_company) { create(:company, subdomain: 'other_sftp') }

        it 'should return Forbidden status ' do
          allow(controller).to receive(:current_company).and_return(other_company)
          delete :destroy, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end
    end

    context 'should destroy sftp' do
      context 'if current_user is admin' do
        it 'should return No content status and decrease sftp count' do
          allow(controller).to receive(:current_user).and_return(admin)
          delete :destroy, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(204)
          expect(Sftp.count).to eq(0)
        end
      end

      context 'if current_user is super admin' do
        it 'should return No content status and decrease sftp count' do
          allow(controller).to receive(:current_user).and_return(super_admin)
          delete :destroy, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(204)
          expect(Sftp.count).to eq(0)
        end
      end
    end
  end

  describe 'Sftp feature flag' do
    context 'should return the status of sftp request as success or forbidden for paginated action' do
      it 'should return the status code of 403' do
        company.stub(:sftp_feature_flag) { false }
        get :paginated, format: :json
        expect(response.status).to eq(403)
      end

      it 'should return the status code of 200' do
        get :paginated, format: :json
        expect(response.status).to eq(200)
      end
    end

    context 'should return the status of sftp request as success or forbidden for create action' do
      it 'should return the status code of 403' do
        company.stub(:sftp_feature_flag) { false }
        post :create, format: :json
        expect(response.status).to eq(403)
        expect(response.message).to eq('Forbidden')
      end

      it 'should return the status code of 201' do
        post :create, params: { name: 'name', host_url: 'hosturl', authentication_key_type: 'credentials', user_name: 'username' ,encrypted_password: 'password', port: 8080, folder_path: 'folderpath', updated_by_id: admin.id, company_id: company.id }, format: :json
        expect(response.status).to eq(201)
        expect(response.message).to eq('Created')
      end
    end

    context 'should return the status of sftp request as success or forbidden for destroy action' do
      it 'should return the status code of 403' do
        company.stub(:sftp_feature_flag) { false }
        delete :destroy, params: { id: sftp.id }, format: :json
        expect(response.status).to eq(403)
        expect(response.message).to eq('Forbidden')
      end

      it 'should return the status code of 204' do
        delete :destroy, params: { id: sftp.id }, format: :json
        expect(response.status).to eq(204)
      end
    end

    context 'should return the status of sftp request as success or forbidden for show action' do
      it 'should return the status code of 403' do
        company.stub(:sftp_feature_flag) { false }
        get :show, params: { id: sftp.id }, format: :json
        expect(response.status).to eq(403)
        expect(response.message).to eq('Forbidden')
      end

      it 'should return the status code of 200 and response message as ok' do
        get :show, params: { id: sftp.id }, format: :json
        expect(response.status).to eq(200)
        expect(response.message).to eq('OK')
      end
    end

    context 'should return the status of sftp request as success or forbidden for update action' do
      it 'should return the status code of 403' do
        company.stub(:sftp_feature_flag) { false }
        put :update, params: { id: sftp.id }, format: :json
        expect(response.status).to eq(403)
        expect(response.message).to eq('Forbidden')
      end

      it 'should return the status code of 200 and response message as ok' do
        put :update, params: { id: sftp.id }, format: :json
        expect(response.status).to eq(200)
        expect(response.message).to eq('OK')
      end
    end

    context 'should return the status of sftp request as success or forbidden for duplicate action' do
      it 'should return the status code of 403' do
        company.stub(:sftp_feature_flag) { false }
        post :create, params: { name: 'name', host_url: 'hosturl', authentication_key_type: 'credentials', port: 8080, user_name: 'username', updated_by_id: super_admin.id ,encrypted_password: 'password', folder_path: 'folderpath', company_id: company.id }, format: :json
        expect(response.status).to eq(403)
        expect(response.message).to eq('Forbidden')
      end

      it 'should return the status code of 200 and response message as ok' do
        post :create, params: { name: 'name', host_url: 'hosturl', authentication_key_type: 'credentials', port: 8080, user_name: 'username', updated_by_id: super_admin.id ,encrypted_password: 'password', folder_path: 'folderpath', company_id: company.id }, format: :json
        expect(response.status).to eq(201)
        expect(response.message).to eq('Created')
      end
    end
  end

  describe 'get #show' do
    context 'should not get sftp' do
      context 'if current_user is not present' do
        it 'should return Unauthorized status' do
          allow(controller).to receive(:current_user).and_return(nil)
          get :show, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(401)
          expect(response.message).to eq('Unauthorized')
        end
      end

      context 'if current_company is not present' do
        it 'should return Not found status ' do
          allow(controller).to receive(:current_company).and_return(nil)
          get :show, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(404)
          expect(response.message).to eq('Not Found')
        end
      end

      context 'if current_user is of other company' do
        let(:other_company) { create(:company, subdomain: 'other_sftp') }

        it 'should return Forbidden status ' do
          allow(controller).to receive(:current_company).and_return(other_company)
          get :show, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end

      context 'if current_user is employee' do
        it 'should return forbidden status ' do
          allow(controller).to receive(:current_user).and_return(employee)
          get :show, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end

       context 'if current_user is manager' do
        it 'should return forbidden status ' do
          allow(controller).to receive(:current_user).and_return(manager.reload)
          get :show, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end
    end

    context 'should get sftp' do
      context 'if current_user is admin' do
        it 'should return Ok status' do
          allow(controller).to receive(:current_user).and_return(super_admin)
          get :show, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(200)
          expect(response.message).to eq('OK')
        end
      end

      context 'if current_user is super admin' do
        it 'should return Ok status' do
          allow(controller).to receive(:current_user).and_return(super_admin)
          get :show, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(200)
          expect(response.message).to eq('OK')
        end
      end

      context 'if request is successful' do
        it 'should return 200 status and 8 keys of sftp and valid keys of sftp' do
          get :show, params: { id: sftp.id } , format: :json
          expect(JSON.parse(response.body).keys.count).to eq(9)
          expect(JSON.parse(response.body).keys).to eq(['name', 'host_url', 'authentication_key_type', 'user_name', 'password', 'port', 'folder_path', 'id', 'public_key'])
        end
      end
    end
  end

  describe 'post #update' do
    context 'should not update sftp' do
      context 'if current_user is not present' do
        it 'should return Unauthorized status' do
          allow(controller).to receive(:current_user).and_return(nil)
          post :update, params: { id: sftp.id, name: 'name', host_url: 'hosturl' }, format: :json
          expect(response.status).to eq(401)
          expect(response.message).to eq('Unauthorized')
        end
      end

      context 'if current_company is not present' do
        it 'should return Not found status ' do
          allow(controller).to receive(:current_company).and_return(nil)
          post :update, params: { id: sftp.id, name: 'name' }, format: :json
          expect(response.status).to eq(404)
          expect(response.message).to eq('Not Found')
        end
      end

      context 'if current_user is of other company' do
        let(:other_company) { create(:company, subdomain: 'other_sftp') }

        it 'should return Forbidden status ' do
          allow(controller).to receive(:current_company).and_return(other_company)
          post :update, params: { id: sftp.id, name: 'name' }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end

      context 'if current_user is employee' do
        it 'should return forbidden status ' do
          allow(controller).to receive(:current_user).and_return(employee)
          post :update, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end
    end

    context 'should update sftp' do
      context 'if current_user is admin' do
        it 'should return created status and sftp count is one' do
          allow(controller).to receive(:current_user).and_return(admin)
          post :update, params: { id: sftp.id, name: 'name', host_url: 'hosturl', authentication_key_type: 'credentials', password: 'password', port: 8080, folder_path: 'folderpath', updated_by_id: admin.id, company_id: company.id }, as: :json
          expect(response.status).to eq(201)
          expect(response.message).to eq('Created')
          expect(Sftp.count).to eq(1)
        end
      end

      context 'if current_user is super admin' do
        it 'should return created status and sftp count is one' do
          allow(controller).to receive(:current_user).and_return(super_admin)
          post :update, params: { id: sftp.id, name: 'name', host_url: 'hosturl', authentication_key_type: 'credentials', password: 'password', port: 8080, folder_path: 'folderpath', updated_by_id: admin.id, company_id: company.id }, as: :json
          expect(response.status).to eq(201)
          expect(response.message).to eq('Created')
          expect(Sftp.count).to eq(1)
        end
      end
    end
  end

  describe 'post #duplicate' do
    context 'should not duplicate sftp' do
      context 'if current_user is not present' do
        it 'should return Unauthorized status' do
          allow(controller).to receive(:current_user).and_return(nil)
          post :duplicate, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(401)
          expect(response.message).to eq('Unauthorized')
        end
      end

      context 'if current_company is not present' do
        it 'should return Not found status ' do
          allow(controller).to receive(:current_company).and_return(nil)
          post :duplicate, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(404)
          expect(response.message).to eq('Not Found')
        end
      end

      context 'if current_user is of other company' do
        let(:other_company) { create(:company, subdomain: 'other_sftp') }

        it 'should return Forbidden status ' do
          allow(controller).to receive(:current_company).and_return(other_company)
          post :duplicate, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end

      context 'if current_user is employee' do
        it 'should return forbidden status ' do
          allow(controller).to receive(:current_user).and_return(employee)
          post :duplicate, params: { id: sftp.id }, format: :json
          expect(response.status).to eq(403)
          expect(response.message).to eq('Forbidden')
        end
      end
    end

    context 'should duplicate sftp' do
      context 'if current_user is admin' do
        it 'should return created status and sftp count is one' do
          allow(controller).to receive(:current_user).and_return(admin)
          post :update, params: { id: sftp.id }, as: :json
          expect(response.status).to eq(201)
          expect(response.message).to eq('Created')
          expect(Sftp.count).to eq(1)
        end
      end

      context 'if current_user is super admin' do
        it 'should return created status and sftp count is one' do
          allow(controller).to receive(:current_user).and_return(super_admin)
          post :update, params: { id: sftp.id }, as: :json
          expect(response.status).to eq(201)
          expect(response.message).to eq('Created')
          expect(Sftp.count).to eq(1)
        end
      end
    end
  end
end
