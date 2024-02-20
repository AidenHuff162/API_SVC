require 'rails_helper'

RSpec.describe Api::V1::WorkspaceImagesController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :invited, company: company) }

  before do
    # sign_in user
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "GET #index" do
    context 'should return workspace images' do
      it 'should return all workspace images' do
        get :index, format: :json
        images = JSON.parse(response.body)

        expect(images.count).to eq(WorkspaceImage.count)
        expect(response.status).to eq(200)
      end
    end
  end
end
