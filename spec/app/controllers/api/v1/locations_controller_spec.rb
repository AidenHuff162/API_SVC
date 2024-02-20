require 'rails_helper'

RSpec.describe Api::V1::LocationsController, type: :controller do
  let(:current_company) { create(:company_with_team_and_location) }
  let(:user) { create(:peter, company: current_company) }
  
  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(current_company)
  end

  describe 'Get #people_page_index' do
    context 'Admin' do
      it 'should be able to get people page index' do
        get :people_page_index, format: :json
        expect(response).to have_http_status(200)
      end

      it 'should not be able tso get people page index with no access permission' do
        user.user_role.permissions["platform_visibility"]["people"] = "no_access"
        user.save!
        get :people_page_index, format: :json
        expect(response).to have_http_status(403)
      end
    end
  end

end
