require 'rails_helper'

RSpec.describe Api::V1::Admin::FieldHistoriesController, type: :controller do
  let(:company) { create(:company) }
  let(:company2) { create(:company, subdomain: 'secondcom') }
  let!(:user2){ create(:user_with_field_history, :profile_field_history, email: 'user2@mail.com', personal_email: 'user2@personalemail.com', company: company2) }
  let!(:user) { create(:user_with_field_history, :profile_field_history, company: company) }
  let(:sarah) { create(:sarah, company: company) }

  before do
    allow(controller).to receive(:current_user).and_return(sarah)
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe 'authorisation' do
    context 'user of (different) company' do
      it 'cannot manage field histories of company2' do
        ability = Ability.new(sarah)
        assert ability.cannot?(:manage, user2.profile.field_histories.first)
      end
    end
    context 'user of company' do
      it 'can manage field histories of company' do
        ability = Ability.new(sarah)
        assert ability.can?(:manage, user.profile.field_histories.first)
      end
    end
    context 'custom field of company' do
      it 'can manage history of custom field' do
        custom_field = create(:custom_field, company: company)
        field_history = create(:field_history, field_name: custom_field.name, field_changer: sarah, field_type: 1, field_auditable_type: 'User', field_auditable_id: user.id, new_value: 'hello', custom_field: custom_field)
        ability = Ability.new(sarah)
        assert ability.can?(:manage, field_history)
      end
    end
    context 'custom field of company2' do
      it 'cannot manage history of custom field' do
        custom_field = create(:custom_field, company: company2)
        field_history = create(:field_history, field_name: custom_field.name, field_changer: user2, field_type: 1, field_auditable_type: 'User', field_auditable_id: user2.id, new_value: 'hello', custom_field: custom_field)
        ability = Ability.new(sarah)
        assert ability.cannot?(:manage, field_history)
      end
    end
  end

  describe '#index' do

    context 'unauthenticated user' do
      it 'should not return any data' do
        allow(controller).to receive(:current_user).and_return(nil)
        response = get :index, params: { field_name: "About", resource_id: user.id, resource_type: "Profile", user_id: user.id }, format: :json
        expect(response.status).to eq(403)
      end
    end

    context 'for authenticated user' do
      context 'having same company' do
        it 'should return field histories belonging to the same company' do
          response = get :index, params: { field_name: "About", resource_id: user.id, resource_type: "Profile", user_id: user.id }, format: :json
          expect(JSON.parse(response.body)[0]["field_name"]).to eq("About You")
        end
      end

      context 'having different comapny' do
        it 'should not return any data' do
          response = get :index, params: { field_name: "About", resource_id: user2.id, resource_type: "Profile", user_id: user2.id }, format: :json
          expect(JSON.parse(response.body).size).to eq(0)
        end
      end

      context 'field history for multiple companies in database' do
        it 'should only fetch historic data of users belonging to current company' do
          response = get :index, params: { field_name: "About", resource_id: user.id, resource_type: "Profile", user_id: user.id }, format: :json
          expect(JSON.parse(response.body).size).to eq(1)
        end
        it 'should fetch profile field history for profile of user belonging to current_company' do
          profile_id = user.profile.id
          response = get :index, params: { field_name: "About", resource_id: user.id, resource_type: "Profile", user_id: user.id }, format: :json
          expect(JSON.parse(response.body)[0]["field_auditable_id"]).to eq(profile_id)
        end
        it 'should not fetch profile field hisotry for profile of user not belonging to current_company' do
          profile_id = user2.profile.id
          response = get :index, params: { field_name: "About", resource_id: user2.id, resource_type: "Profile", user_id: user2.id }, format: :json
          expect(JSON.parse(response.body).size).to eq(0)
        end
      end

      context 'current user not having permission' do
        before do
          user_role = sarah.company.user_roles.where(role_type: 'employee').take
          user_role.permissions['platform_visibility']['profile_info'] = 'no_access'
          user_role.save!
          sarah.update(user_role_id: user_role.id)
        end
        it 'should return with error status' do
          response = get :index, params: { field_name: "About", resource_id: sarah.id, resource_type: "Profile", user_id: sarah.id }, format: :json
          expect(response.status).to eq(403)
        end
      end

      context 'having multiple field histories against one user' do
        before do
          field_history = create(:field_history, field_name: 'About You', field_changer: user, field_type: 6, field_auditable_type: 'Profile', field_auditable_id: user.profile.id, new_value: 'hello')
        end
        it 'should return all field histories' do
          response = get :index, params: { field_name: "About", resource_id: user.id, resource_type: "Profile", user_id: user.id }, format: :json
          expect(JSON.parse(response.body).size).to eq(2)
        end
      end
    end

  end

  describe '#update' do
    context 'authenticated user' do
      it 'should update the field_history' do
        field_history = user.profile.field_histories.first
        response = put :update, params: { id: field_history.id, field_name: 'About You', new_value: 'Updated text', field_changer: {name: sarah.full_name, title: sarah.title}, field_type: 'text', field_auditable_type: 'Profile', field_auditable_id: user.profile.id }, format: :json
        expect(user.profile.field_histories.first.new_value).to eq('Updated text')
      end
    end

    context 'user and current user beloging to different company' do
      it 'should return unauthorise status' do
        field_history = user2.profile.field_histories.first
        response = put :update, params: { id: field_history.id, field_name: 'About You', new_value: 'Updated text', field_changer: {name: user2.full_name, title: user2.title}, field_type: 'text', field_auditable_type: 'Profile', field_auditable_id: user2.profile.id }, format: :json
        expect(response.status).to eq(403)
      end
    end

    context 'unauthenticated user' do
      it 'should not update any data' do
        allow(controller).to receive(:current_user).and_return(nil)
        field_history = user.profile.field_histories.first
        response = put :update, params: { id: field_history.id, field_name: 'About You', new_value: 'Updated text', field_changer: {name: sarah.full_name, title: sarah.title}, field_type: 'text', field_auditable_type: 'Profile', field_auditable_id: user.profile.id }, format: :json
        expect(response.status).to eq(403)
      end
    end
  end

  describe '#destroy' do
    context 'authenticated user' do
      it 'should destroy the field_history' do
        field_history = user.profile.field_histories.first
        response = delete :destroy, params: { id: field_history.id, field_auditable_type: 'Profile', field_auditable_id: user.profile.id }, format: :json
        expect(user.reload.profile.field_histories.size).to eq(0)
      end
    end

    context 'user and current user beloging to different company' do
      it 'should return unauthorise status' do
        field_history = user2.profile.field_histories.first
        response = delete :destroy, params: { id: field_history.id, field_auditable_type: 'Profile', field_auditable_id: user2.profile.id }, format: :json
        expect(response.status).to eq(403)
      end
    end

    context 'unauthenticated user' do
      it 'should not destroy data' do
        allow(controller).to receive(:current_user).and_return(nil)
        field_history = user.profile.field_histories.first
        response = delete :destroy, params: { id: field_history.id, field_auditable_type: 'Profile', field_auditable_id: user.profile.id }, format: :json
        expect(response.status).to eq(403)
      end
    end
  end

  describe '#showssn' do

    context 'current_user and user beloging to same company' do
      before do
        @ssn_value = '212-32-1321'
        @field_history = create(:field_history, field_name: 'Social Security Number', field_changer: sarah, field_type: 1, field_auditable_type: 'User', field_auditable_id: user.id, new_value: @ssn_value)
        @response = get :show_identification_numbers, params: { field_auditable_id: user.id, field_auditable_type: 'User', indentification_edit: true, id: @field_history.id }, format: :json
      end
      it 'should return ssn' do
        expect(JSON.parse(@response.body)["id"]).to eq(@field_history.id)
      end
      it 'should return ssn for the same user' do
        expect(JSON.parse(@response.body)["field_auditable_id"]).to eq(user.id)
      end
      it 'should return accurate ssn value' do
        expect(JSON.parse(@response.body)['new_value']).to eq(@ssn_value)
      end
    end

    context 'current_user and user belonging to different company' do
      it 'should not return ssn' do
        sarah2 = create(:user, company: company2)
        field_history = create(:field_history, field_name: 'Social Security Number', field_changer: sarah2, field_type: 1, field_auditable_type: 'User', field_auditable_id: user2.id, new_value: '212-32-1321')
        response = get :show_identification_numbers, params: { field_auditable_id: user.id, field_auditable_type: 'User', indentification_edit: true, id: field_history.id }, format: :json
        expect(response.status).to eq(403)
      end
    end

    context 'unauthenticated user' do
      it 'should not show ssn' do
        allow(controller).to receive(:current_user).and_return(nil)
        field_history = create(:field_history, field_name: 'Social Security Number', field_changer: sarah, field_type: 1, field_auditable_type: 'User', field_auditable_id: user.id, new_value: '212-32-1321')
        response = get :show_identification_numbers, params: { field_auditable_id: user.id, field_auditable_type: 'User', indentification_edit: true, id: field_history.id }, format: :json
        expect(response.status).to eq(403)
      end
    end
  end

end
