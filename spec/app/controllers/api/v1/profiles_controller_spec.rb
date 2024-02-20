require 'rails_helper'

RSpec.describe Api::V1::ProfilesController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:tim) { create(:tim, state: :active, current_stage: :registered, company: company) }
  let(:marketing) { create(:team, company: company, name: 'Marketing') }
  let(:valid_session) { {} }
  let(:tim_profile) { tim.profile }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "PUT #update" do
    context "should not update profile" do
      context 'if user is unauthenticated' do
        before do
          allow(controller).to receive(:current_user).and_return(nil)
          post :update, params: { id: tim_profile.id, user_id: tim_profile.user_id, linkedin: "linkedin_test" }, format: :json
        end

        it "should return unauthorised status" do
          expect(response.status).to eq(401)
        end
      end

      context "if user of other company" do
        let(:other_company) { create(:company, subdomain: 'boo') }
        let(:other_user) { create(:user, company: other_company) }

        it 'should return forbidden status' do
          post :update, params: { id: other_user.profile.id, user_id: other_user, linkedin: "linkedin_test" }, format: :json
          expect(response.status).to eq(403)
        end

        it 'should return forbidden status' do
          allow(controller).to receive(:current_user).and_return(other_user)
          post :update, params: { id: tim_profile.id, user_id: tim_profile.user_id, linkedin: "linkedin_test" }, format: :json
          expect(response.status).to eq(403)
        end
      end
    end

    context 'should update profile' do
      before do
        post :update, params: { id: tim_profile.id, user_id: tim_profile.user_id, facebook: "facebook_test", twitter: "twitter_test", github: "github_test", linkedin: "linkedin_test", about_you: "about_you_test" }, format: :json
        tim_profile.reload
      end

      it "should update the user's profile facebook" do
        expect(tim_profile.facebook).to eq("facebook_test")
      end

      it "should update the user's profile twitter" do
        expect(tim_profile.twitter).to eq("twitter_test")
      end

      it "should update the user's profile github" do
        expect(tim_profile.github).to eq("github_test")
      end

      it "should update the user's profile linkedin" do
        expect(tim_profile.linkedin).to eq("linkedin_test")
      end

      it "should update the user's profile about_you" do
        expect(tim_profile.about_you).to eq("about_you_test")
      end

      it "should create five histories field" do
        expect(tim_profile.field_histories.size).to eq(5)
      end
    end

  end
end
