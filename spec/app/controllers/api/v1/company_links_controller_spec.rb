require 'rails_helper'

RSpec.describe Api::V1::Admin::CompanyLinksController, type: :controller do

  let(:company) { create(:company_with_team_and_location) }
  let(:user) { create(:nick, company: company) }

  describe "GET #index" do

    before do
      allow(controller).to receive(:current_company).and_return(user.company)
      allow(controller).to receive(:current_user).and_return(user)
    end

    it "should retrieve company links ordered by position" do
      create(:company_link, company: company, position: 0)
      create(:company_link, company: company, position: 1)
      create(:company_link, company: company, position: 2)
      get :index, params: { employee_id: user.id }, format: :json
      expect(response.status).to eq(200)
      links = JSON.parse(response.body)["company_links"]
      expect(links.length).to eq(3)
      expect(links[0]["position"]).to eq(0)
      expect(links[1]["position"]).to eq(1)
      expect(links[2]["position"]).to eq(2)
    end

    context 'shoul return links according to lde of employee' do
      let!(:link1) {create(:company_link, company: company, position: 0)}
      let!(:link2) {create(:company_link, company: company, position: 1, location_filters: [company.locations.first.id])}
      let!(:link3) {create(:company_link, company: company, position: 2, team_filters: [company.teams.first.id])}
      let!(:link4) {create(:company_link, company: company, position: 2, status_filters: [company.custom_fields.where(field_type: CustomField.field_types['employment_status']).first.custom_field_options.take.option])}

      context 'location filter' do
        it 'should return the links having same location as user and links with location as all' do
          user.update(location_id: link2.location_filters.first)
          get :index, params: { employee_id: user.id }, format: :json
          expect(response.status).to eq(200)
          links = JSON.parse(response.body)["company_links"]
          expect(links.length).to eq(2)
          expect(links.map {|l| l['id']}.include?(link2.id)).to eq(true)
          expect(links.map {|l| l['id']}.include?(link1.id)).to eq(true)
        end

        it 'should only return the links with location as all' do
          get :index, params: { employee_id: user.id }, format: :json
          expect(response.status).to eq(200)
          links = JSON.parse(response.body)["company_links"]
          expect(links.length).to eq(1)
          expect(links.map {|l| l['id']}.include?(link1.id)).to eq(true)
        end
      end

      context 'team filter' do
        it 'should return the links having same team as user and links with team as all' do
          user.update(team_id: link3.team_filters.first)
          get :index, params: { employee_id: user.id }, format: :json
          expect(response.status).to eq(200)
          links = JSON.parse(response.body)["company_links"]
          expect(links.length).to eq(2)
          expect(links.map {|l| l['id']}.include?(link3.id)).to eq(true)
          expect(links.map {|l| l['id']}.include?(link1.id)).to eq(true)
        end

        it 'should only return the links with team as all' do
          get :index, params: { employee_id: user.id }, format: :json
          expect(response.status).to eq(200)
          links = JSON.parse(response.body)["company_links"]
          expect(links.length).to eq(1)
          expect(links.map {|l| l['id']}.include?(link1.id)).to eq(true)
        end
      end

      context 'status filter' do
        it 'should return the links having same status as user and links with status as all' do
          custom_field = company.custom_fields.where(field_type: CustomField.field_types['employment_status']).first
          create(:custom_field_value, user: user, custom_field: custom_field, custom_field_option: custom_field.custom_field_options.take)
          get :index, params: { employee_id: user.id }, format: :json
          expect(response.status).to eq(200)
          links = JSON.parse(response.body)["company_links"]
          expect(links.length).to eq(2)
          expect(links.map {|l| l['id']}.include?(link4.id)).to eq(true)
          expect(links.map {|l| l['id']}.include?(link1.id)).to eq(true)
        end

        it 'should only return the links with team as all' do
          get :index, params: { employee_id: user.id }, format: :json
          expect(response.status).to eq(200)
          links = JSON.parse(response.body)["company_links"]
          expect(links.length).to eq(1)
          expect(links.map {|l| l['id']}.include?(link1.id)).to eq(true)
        end
      end

      it 'should return all links ' do
        custom_field = company.custom_fields.where(field_type: CustomField.field_types['employment_status']).first
        create(:custom_field_value, user: user, custom_field: custom_field, custom_field_option: custom_field.custom_field_options.take)
        user.update(team_id: link3.team_filters.first, location_id: link2.location_filters.first)
        get :index, params: { employee_id: user.id }, format: :json
        expect(response.status).to eq(200)
        links = JSON.parse(response.body)["company_links"]
        expect(links.length).to eq(4)
      end
    end
  end

end
