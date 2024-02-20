require 'rails_helper'

RSpec.describe Api::V1::Auth::PasswordsController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:nick, company: company) }

  describe "Forget password" do
    it "should give error for faulty email" do
      @request.env["devise.mapping"] = Devise.mappings[:user]
      response = post :create, params: { email: 'wrong_email@test.com', redirect_url: 'https://' + company.subdomain + '.test.com'  }, format: :json
      result = JSON.parse response.body
      expect(result['errors'][0]).to eq(I18n.t('reset.reset_password_message'))
    end
  end

end
