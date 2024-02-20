require 'rails_helper'

RSpec.describe Api::V1::RecaptchaController, type: :controller do
  let(:company) { create(:company) }

  before do
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe 'verify' do
    before do
      stub_request(:post, "https://www.google.com/recaptcha/api/siteverify?secret=#{ENV['RECAPTCHA_SECRET_KEY']}&response=g_recaptcha_response").to_return(body: JSON.generate({'success': 'true'}))
      stub_request(:post, "https://www.google.com/recaptcha/api/siteverify?secret=#{ENV['RECAPTCHA_SECRET_KEY']}&response=g_recaptcha_responses").to_return(body: JSON.generate({'success': 'fasle'}))
    end
    it 'should verify the user' do
      get :verify, params: { response: "g_recaptcha_response" }, format: :json
      expect(JSON.parse(response.body)["success"]).to eq("true")
    end

    it 'should noyt verify the user with invalid response' do
      get :verify, params: { response: "g_recaptcha_responses" }, format: :json
      expect(JSON.parse(response.body)["success"]).to_not eq("true")
    end
  end


end
