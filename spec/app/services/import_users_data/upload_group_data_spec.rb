require 'rails_helper'
RSpec.describe ImportUsersData::UploadGroupData do
  let!(:company) { create(:company) }
  let!(:sarah) { create(:sarah, company: company) }
  let!(:user) { create(:user, company: company) }

  describe 'flatfile group options update' do
    context 'Updating group options through flatfile' do
      it 'should create location options' do
        data = [{ 'Group Type' => 'Location', 'Group Name' => 'locate' }]
        args = { company: company, data: data, current_user: sarah, upload_date: Date.today.to_s }
        ::ImportUsersData::UploadGroupData.new(args).perform
        expect(company.locations.where(name: 'locate').count).to eq(1)
      end

      it 'should not create location option if already exists' do
        company.locations.create(name: 'locate')
        data = [{ 'Group Type' => 'Location', 'Group Name' => 'locate' }]
        args = { company: company, data: data, current_user: sarah, upload_date: Date.today.to_s }
        ::ImportUsersData::UploadGroupData.new(args).perform
        expect(company.locations.where(name: 'locate').count).not_to eq(2)
      end

      it 'should create department options' do
        data = [{ 'Group Type' => 'Department', 'Group Name' => 'locate' }]
        args = { company: company, data: data, current_user: sarah, upload_date: Date.today.to_s }
        ::ImportUsersData::UploadGroupData.new(args).perform
        expect(company.teams.where(name: 'locate').count).to eq(1)
      end

      it 'should not create department option if already exists' do
        company.teams.create(name: 'locate')
        data = [{ 'Group Type' => 'Department', 'Group Name' => 'locate' }]
        args = { company: company, data: data, current_user: sarah, upload_date: Date.today.to_s }
        ::ImportUsersData::UploadGroupData.new(args).perform
        expect(company.teams.where(name: 'locate').count).not_to eq(2)
      end

      it 'should create custom group options' do
        custom_field = company.custom_fields.where.not(integration_group: nil).first
        data = [{ 'Group Type' => custom_field.name, 'Group Name' => 'locate' }]
        args = { company: company, data: data, current_user: sarah, upload_date: Date.today.to_s }
        ::ImportUsersData::UploadGroupData.new(args).perform
        expect(custom_field.custom_field_options.where(option: 'locate').count).to eq(1)
      end

      it 'should not create custom group options if already exists' do
        custom_field = company.custom_fields.where.not(integration_group: nil).first
        custom_field.custom_field_options.create(option: 'locate')
        data = [{ 'Group Type' => custom_field.name, 'Group Name' => 'locate' }]
        args = { company: company, data: data, current_user: sarah, upload_date: Date.today.to_s }
        ::ImportUsersData::UploadGroupData.new(args).perform
        expect(custom_field.custom_field_options.where(option: 'locate').count).not_to eq(2)
      end
    end
  end
end
