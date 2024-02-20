require 'rails_helper'

RSpec.describe Api::V1::Admin::CustomFieldOptionsController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:gender) { create(:custom_field, name: 'Gender A', section: 'personal_info', field_type: 'mcq', company: company) }
  let(:female) {create(:custom_field_option, option: 'female', position: 0, custom_field: gender)}

  let(:company2) { create(:company, subdomain: 'rock') }
  let(:user2) { create(:user, state: :active, current_stage: :registered, company: company2) }
  let(:fav_color) { create(:custom_field, name: 'Favorite Color', section: 'personal_info', field_type: 'mcq', company: company2) }
  let(:red) {create(:custom_field_option, option: 'red', custom_field: fav_color)}

  before do
    red.reload
    fav_color.reload
    female.reload
    gender.reload
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe 'authorization' do
    context 'user of (different) company' do
      it 'cannot manage custom field options of different company' do
        ability = Ability.new(user2)
        expect(ability.cannot?(:manage, female)).to eq(true)
      end
    end

    context 'user of company' do
      it 'can manage custom field options of his company' do
        ability = Ability.new(user2)
        expect(ability.can?(:manage, red)).to eq(true)
      end
    end

    context 'custom field options of custom field with same company' do
      it 'can manage custom field option of custom field' do
        ability = Ability.new(user2)
        expect(ability.can?(:manage, fav_color.custom_field_options.first)).to eq(true)
      end
    end

    context 'custom field options of custom field with different company' do
      it 'cannot manage custom field option of custom field' do
        ability = Ability.new(user)
        expect(ability.cannot?(:manage, fav_color.custom_field_options.first)).to eq(true)
      end
    end
  end

  describe "POST #create" do
    context 'unauthenticated user' do
      it 'should not return any data' do
        allow(controller).to receive(:current_user).and_return(nil)
        response = post :create, params: { custom_field: gender, option: 'Male', active: true }, format: :json
        expect(response.status).to eq(401)
      end
    end

    context "authenticated user" do
      it "should create custom field options" do
        post :create, params: { custom_field: gender, option: 'Male', active: true }, format: :json
        expect(response.message).to eq("Created")
      end
    end
  end

  describe "POST #update" do
    context 'unauthenticated user' do
      it 'should not return any data' do
        allow(controller).to receive(:current_user).and_return(nil)
        response = post :update, params: { id: female.id, custom_field_id: gender.id, option: 'fe-male', position: 1 }, format: :json
        expect(response.status).to eq(401)
      end
    end

    context 'authenticated user' do
      it "should update custom field option name" do
        post :update, params: { id: female.id, custom_field_id: gender.id, option: 'fe-male', position: 1 }, format: :json
        gender.reload
        expect(JSON.parse(response.body)["option"]).to eq('fe-male')
      end
    end
  end
end
