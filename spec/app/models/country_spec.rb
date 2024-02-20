require 'rails_helper'

RSpec.describe Country, type: :model do
  let!(:country) { create(:country) }

  describe 'Associations' do
    it { is_expected.to have_many(:states)}
  end

  describe 'Validation' do
    it { expect(Country.new).to be_valid }
  end

  describe 'Default values and updation changes' do
    it 'Checks for default values for the record after create' do
      country = Country.create!
      expect(country.areacode_type).to eq("Zip")
      expect(country.city_type).to eq("City")
    end

    it 'Sets code and city type' do 
      country.update(areacode_type: "Postal", city_type:"District", name: 'City Name' )
      expect(country.areacode_type).to eq("Postal")
      expect(country.city_type).to eq("District")
      expect(country.name).to eq("City Name")
    end
  end   
end
