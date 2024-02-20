require 'rails_helper'
RSpec.describe ImportUsersData::UploadHolidayData do
  let!(:company) { create(:company) }
  let!(:sarah) { create(:sarah, company: company) }
  let!(:user) { create(:user, company: company) }
  let!(:location) { create(:location, company: company) }

  describe 'flatfile holidays update' do
    context 'Updating holidays through flatfile' do
      it 'should create holiday' do
        data = [{ 'Holiday Name' => 'New Year', 'Start Date' => '12/31/222', 'End Date' => '', 'Locations' => location.name, 'Departments' => 'all', 'Employment Status' => 'all' }]
        args = { company: company, data: data, current_user: sarah, upload_date: Date.today.to_s }
        ::ImportUsersData::UploadHolidayData.new(args).perform
        expect(company.holidays.where(name: 'New Year').count).to eq(1)
      end

      it 'should not create holidays if start date is not present' do
        data = [{ 'Holiday Name' => 'Thanks Giving', 'Start Date' => '', 'End Date' => '', 'Locations' => location.name, 'Departments' => 'all', 'Employment Status' => 'all' }]
        args = { company: company, data: data, current_user: sarah, upload_date: Date.today.to_s }
        ::ImportUsersData::UploadHolidayData.new(args).perform
        expect(company.holidays.where(name: 'Thanks Giving').count).to eq(0)
      end

      it 'should not create holidays if holiday name is not present' do
        data = [{ 'Holiday Name' => '', 'Start Date' => '12/31/2022', 'End Date' => '', 'Locations' => location.name, 'Departments' => 'all', 'Employment Status' => 'all' }]
        args = { company: company, data: data, current_user: sarah, upload_date: Date.today.to_s }
        ::ImportUsersData::UploadHolidayData.new(args).perform
        expect(company.holidays.count).to eq(0)
      end
    end
  end
end
