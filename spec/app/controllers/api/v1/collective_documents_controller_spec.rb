require 'rails_helper'

RSpec.describe Api::V1::CollectiveDocumentsController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  before do
    # sign_in user
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "GET #paginated_documents" do
    it 'should return user paginated collective documents' do
      get :paginated_documents, params: {user_id: user.id, start: 0, length: 10, order_column: 'id', order_in: 'asc', term: nil}, as: :json
      documents = JSON.parse(response.body)
      expect(documents.present?).to eq(true)
      expect(response.status).to eq(200)
    end
  end
end