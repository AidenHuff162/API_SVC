require 'rails_helper'

RSpec.describe Api::V1::Admin::HolidaysController, type: :controller do
	let(:location) { create(:location) }
	let(:team) { create(:team) }
	let(:user) { create(:user, team: team, location: location) }

	before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

	describe "holidays" do

    it "should fetch user holidays" do
    	holiday = FactoryGirl.create(:holiday, company: user.company)
      result = get :user_holidays, params: { user_id: user.id }, format: :json
      response = JSON.parse result.body
      expect(response[0]["id"]).to eq(holiday.id)
      expect(result.status).to eq(200)
    end

    it "should not fetch user holidays" do
      holiday = FactoryGirl.create(:holiday)
      result = get :user_holidays, format: :json
      response = JSON.parse result.body
      expect(response.count).to eq(0)
      expect(result.status).to eq(200)
    end

    it "should fetch all holidays" do
    	holiday = FactoryGirl.create(:holiday, company: user.company)
      hashParams = {"draw"=>"1", "columns"=>{"0"=>{"data"=>"name", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}, "1"=>{"data"=>"date_range", "name"=>"", "searchable"=>"true", "orderable"=>"true", "search"=>{"value"=>"", "regex"=>"false"}}, "2"=>{"data"=>"applies_to", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}}, "3"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}}, "4"=>{"data"=>"", "name"=>"", "searchable"=>"true", "orderable"=>"false", "search"=>{"value"=>"", "regex"=>"false"}}}, "order"=>{"0"=>{"column"=>"0", "dir"=>"asc"}}, "start"=>"0", "length"=>"25", "search"=>{"value"=>"", "regex"=>"false"}, "current_year"=> holiday.begin_date.year}
      result = get :holidays_index, params: hashParams, format: :json
      response = JSON.parse result.body
      expect(response["data"][0]["id"]).to eq(holiday.id)
      expect(result.status).to eq(200)
    end

    it "should not fetch all holidays" do
      holiday = FactoryGirl.create(:holiday, company: user.company)
      expect{get :holidays_index, format: :json}.to raise_error
    end

  	it "should update the holiday" do
    	holiday = FactoryGirl.create(:holiday, company: user.company)
      put :update, params: { id: holiday.id, name: "new holiday" }, format: :json
  		holiday.reload
  		expect(holiday.name).to eq("new holiday")
      expect(response.status).to eq(200)
  	end

    it "should not update the holiday" do
      holiday = FactoryGirl.create(:holiday, company: user.company)
      put :update, params: { id: holiday.id + 1, name: "new holiday" }, format: :json
      holiday.reload
      expect(holiday.name).not_to eq("new holiday")
      expect(response.status).to eq(404)
    end

  	it "should delete the holiday" do
    	holiday = FactoryGirl.create(:holiday, company: user.company)
      delete :destroy, params: { id: holiday.id }, format: :json
  		expect(holiday.reload.deleted_at).not_to eq(nil)
  	end

    it "should not delete the holiday" do
      holiday = FactoryGirl.create(:holiday, company: user.company)
      delete :destroy, params: { id: holiday.id + 1 }, format: :json
      expect{holiday.reload}.not_to raise_error
      expect(response.status).to eq(404)
    end
  end
end
