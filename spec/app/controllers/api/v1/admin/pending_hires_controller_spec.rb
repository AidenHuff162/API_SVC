require 'rails_helper'

RSpec.describe Api::V1::Admin::PendingHiresController, type: :controller do

	let!(:current_company) { create(:company, subdomain: 'aceship') }
	let!(:current_user) { create(:user, company: current_company) }
	let!(:incomplete_user_a) { create(:user, company: current_company, current_stage: User.current_stages[:incomplete]) }
	let!(:incomplete_user_b) { create(:user, company: current_company, current_stage: User.current_stages[:incomplete]) }
	let!(:incomplete_but_active_pending_hire) { create(:incomplete_pending_hire, company: current_company, user: incomplete_user_a, personal_email: 'incomplete+active@test.com') }
	let!(:incomplete_but_inactive_pending_hire) { create(:incomplete_pending_hire, company: current_company, user: incomplete_user_b, personal_email: 'incomplete+inactive@test.com', state: 'inactive') }
	let!(:active_pending_hire_a) { create(:pending_hire, company: current_company, personal_email: 'active+1@test.com') }
	let!(:active_pending_hire_b) { create(:pending_hire, company: current_company, personal_email: 'active+2@test.com') }
	let!(:inactive_pending_hire) { create(:pending_hire, company: current_company, personal_email: 'inactive@test.com', state: 'inactive', user: current_user) }

	before do
    allow(controller).to receive(:current_user).and_return(current_user)
    allow(controller).to receive(:current_company).and_return(current_company)
  end

  describe 'GET #index' do
  	context 'should return pending hire index data' do
  		it 'should return ok status and active pending hires' do
  			get :index, format: :json
  			expect(response.status).to eq(200)
  			expect(JSON.parse(response.body).count).to eq(current_company.pending_hires.where(state: 'active').count)
  		end
  	end

  	context 'should not return pending hire index data' do
  		it 'should return unauthorized status for unauthenticated user' do
  			allow(controller).to receive(:current_user).and_return(nil)
  			get :index, format: :json
  			expect(response.status).to eq(401)
  		end

  		it 'should return no content status and empty index data if requesting user belongs to other company' do
  			allow(controller).to receive(:current_user).and_return(create(:user, company: create(:company, subdomain: 'aceship_other')))
  			get :index, format: :json
  			expect(response.status).to eq(204)
  			expect(response.body).to eq("")
  		end
  	end
  end

  describe 'GET #show' do
  	context 'should return pending hire show data' do
  		it 'should return ok status and pending hire of given pending hire id' do
  			get :show, params: { id: inactive_pending_hire.id }, format: :json
  			expect(response.status).to eq(200)
  			expect(JSON.parse(response.body)['id']).to eq(inactive_pending_hire.id)
  		end
  	end

  	context 'should not return pending hire show data' do
  		it 'should return unauthorized status for unauthenticated user' do
  			allow(controller).to receive(:current_user).and_return(nil)
  			get :show, params: { id: inactive_pending_hire.id }, format: :json
  			expect(response.status).to eq(401)
  		end

  		it 'should return no content status and empty index data if requesting user belongs to other company' do
  			allow(controller).to receive(:current_user).and_return(create(:user, company: create(:company, subdomain: 'aceship_other')))
  			get :index, params: { id: inactive_pending_hire.id }, format: :json
  			expect(response.status).to eq(204)
  			expect(response.body).to eq("")
  		end

  		it 'should return not found status and if requesting pending hire id belongs to other company' do
  			get :show, params: { id: create(:pending_hire, company: create(:company, subdomain: 'aceship-test'), personal_email: 'incomplete+active@test.com').id }, format: :json
  			expect(response.status).to eq(404)
  		end
  	end
  end

  describe 'GET #pending_hires_count' do
  	context 'should return pending hire pending_hires_count data' do
  		it 'should return ok status and active pending hires count' do
  			get :pending_hires_count, format: :json
  			expect(response.status).to eq(200)
  			expect(JSON.parse(response.body)['count']).to eq(current_company.pending_hires.where(state: 'active').count)
  		end
  	end

  	context 'should not return pending hire pending_hires_count data' do
  		it 'should return unauthorized status for unauthenticated user' do
  			allow(controller).to receive(:current_user).and_return(nil)
  			get :pending_hires_count, format: :json
  			expect(response.status).to eq(401)
  		end

  		it 'should return no content status and empty index data if requesting user belongs to other company' do
  			allow(controller).to receive(:current_user).and_return(create(:user, company: create(:company, subdomain: 'aceship_other')))
  			get :pending_hires_count, format: :json
  			expect(response.status).to eq(204)
  			expect(response.body).to eq("")
  		end
  	end
  end

  describe 'POST #create' do
  	context 'should create pending hire' do
  		it 'should return ok status and create pending hire' do
  			post :create, params: { first_name: 'Unit', last_name: 'Tester', personal_email: 'testing+create@test.com', state: 'active' }, format: :json
  			expect(response.status).to eq(200)
      	expect(current_company.pending_hires.where(state: 'active').count).to eq(4)
  		end
  	end

  	context 'should not create pending hire' do
  		it 'should return unauthorized status for unauthenticated user' do
  			allow(controller).to receive(:current_user).and_return(nil)
  			post :create, params: { first_name: 'Unit', last_name: 'Tester', personal_email: 'testing+create@test.com', state: 'active' }, format: :json
  			expect(response.status).to eq(401)
  		end

  		it 'should return no content status and not create pending hire if requesting user belongs to other company' do
  			allow(controller).to receive(:current_user).and_return(create(:user, company: create(:company, subdomain: 'aceship_other')))
  			post :create, params: { first_name: 'Unit', last_name: 'Tester', personal_email: 'testing+create@test.com', state: 'active' }, format: :json
  			expect(response.status).to eq(204)
  			expect(current_company.pending_hires.where(state: 'active').count).not_to eq(4)
  		end

  		it 'should should return ok status but not create pending hire if personal email is already exists' do
  			post :create, params: { first_name: 'Unit', last_name: 'Tester', personal_email: active_pending_hire_b.personal_email, state: 'active' }, format: :json
  			expect(response.status).to eq(200)
  			expect(current_company.pending_hires.where(state: 'active').count).not_to eq(4)
  		end
  	end
  end

  describe 'PUT #update' do
  	context 'should update pending hire' do
  		it 'should return no content status and update pending hire' do
  			put :update, params: { id: active_pending_hire_a.id, personal_email: 'testing+update@test.com' }, format: :json
  			expect(response.status).to eq(204)
  			expect(active_pending_hire_a.reload.personal_email).to eq('testing+update@test.com')
  		end
  	end

  	context 'should not update pending hire' do
  		it 'should return unauthorized status for unauthenticated user' do
  			allow(controller).to receive(:current_user).and_return(nil)
  			put :update, params: { id: active_pending_hire_a.id, personal_email: 'testing+update@test.com' }, format: :json
  			expect(response.status).to eq(401)
  		end

  		it 'should return no content status and not update pending hire if requesting user belongs to other company' do
  			allow(controller).to receive(:current_user).and_return(create(:user, company: create(:company, subdomain: 'aceship_other')))
  			put :update, params: { id: active_pending_hire_a.id, personal_email: 'testing+update@test.com' }, format: :json
  			expect(response.status).to eq(204)
  			expect(active_pending_hire_a.reload.personal_email).not_to eq('testing+update@test.com')
  		end
  	end
  end

  describe 'DELETE #destroy' do
  	context 'should delete pending hire' do
  		it 'should return no content status and soft delete pending hire' do
  			delete :destroy, params: { id: active_pending_hire_a.id }, format: :json
  			expect(current_company.pending_hires.find_by_id(active_pending_hire_a.id)).to be_nil
  			expect(current_company.pending_hires.with_deleted.find_by_id(active_pending_hire_a.id).deleted_at).not_to be_nil
  		end

  		it 'should return no content status and soft delete pending hire and its associated user' do
  			delete :destroy, params: { id: incomplete_but_active_pending_hire.id }, format: :json
  			expect(current_company.pending_hires.find_by_id(incomplete_but_active_pending_hire.id)).to be_nil
  			expect(current_company.pending_hires.with_deleted.find_by_id(incomplete_but_active_pending_hire.id).deleted_at).not_to be_nil
  			expect(current_company.users.find_by_id(incomplete_user_a.id)).to be_nil
  			expect(current_company.users.with_deleted.find_by_id(incomplete_user_a).deleted_at).not_to be_nil
  			expect(current_company.users.with_deleted.find_by_id(incomplete_user_a).pending_hire.id).to eq(incomplete_but_active_pending_hire.id)
  		end

  		it 'should return no content status, remove user association id and soft delete pending hire' do
  			delete :destroy, params: { id: inactive_pending_hire.id }, format: :json
  			expect(current_company.pending_hires.find_by_id(inactive_pending_hire.id)).to be_nil
  			expect(current_company.pending_hires.with_deleted.find_by_id(inactive_pending_hire.id).deleted_at).not_to be_nil
  			expect(current_company.pending_hires.with_deleted.find_by_id(inactive_pending_hire.id).user_id).to be_nil
  		end
  	end

  	context 'should not delete pending hire' do
  		it 'should return unauthorized status for unauthenticated user' do
  			allow(controller).to receive(:current_user).and_return(nil)
  			delete :destroy, params: { id: active_pending_hire_a.id }, format: :json
  			expect(response.status).to eq(401)
  			expect(current_company.pending_hires.find_by_id(active_pending_hire_a.id)).not_to be_nil
  		end

  		it 'should return no content status and not destroy pending hire if requesting user belongs to other company' do
  			allow(controller).to receive(:current_user).and_return(create(:user, company: create(:company, subdomain: 'aceship_other')))
  			delete :destroy, params: { id: active_pending_hire_a.id }, format: :json
  			expect(response.status).to eq(204)
  			expect(current_company.pending_hires.find_by_id(active_pending_hire_a.id)).not_to be_nil
  		end
  	end
  end

  describe 'GET #paginated_hires' do
  	context 'should not return pending hire paginated_hires data' do
  		it 'should return unauthorized status for unauthenticated user' do
  			allow(controller).to receive(:current_user).and_return(nil)
  			get :paginated_hires, format: :json
  			expect(response.status).to eq(401)
  		end

  		it 'should return no content status and empty paginated_hires data if requesting user belongs to other company' do
  			allow(controller).to receive(:current_user).and_return(create(:user, company: create(:company, subdomain: 'aceship_other')))
  			get :paginated_hires, format: :json
  			expect(response.status).to eq(204)
  			expect(response.body).to eq("")
  		end
  	end
  end
end
