require 'rails_helper'

RSpec.describe PendingHireServices::GetCsvData do
  let!(:company) {create(:company)}
  let!(:user) {create(:pending_hire, company: company)}
  let!(:user1) {create(:pending_hire, company: company)}

  describe 'get csv data' do
    it 'should return data in array type, with header, of given ids' do
      @result = PendingHireServices::GetCsvData.new.perform([user.id, user1.id], company)

      expect(@result.class).to eq(Array)
      expect(@result.count).to eq(3)
      expect(@result[0]).to eq(["Name", "Job Title", "Department", "Location", "Manager", "Start Date", "Status"])
    end

    it 'should return only headers if ids are nil' do
      @result = PendingHireServices::GetCsvData.new.perform(nil, company)

      expect(@result.class).to eq(Array)
      expect(@result.count).to eq(1)
      expect(@result[0]).to eq(["Name", "Job Title", "Department", "Location", "Manager", "Start Date", "Status"])
    end

    it 'should return only headers if pending hires are not present' do
      @result = PendingHireServices::GetCsvData.new.perform([343,434], company)

      expect(@result.class).to eq(Array)
      expect(@result.count).to eq(1)
      expect(@result[0]).to eq(["Name", "Job Title", "Department", "Location", "Manager", "Start Date", "Status"])
    end
  end
end
