require 'rails_helper'

RSpec.describe Report, type: :model do
  let(:company) { FactoryGirl.create(:company, subdomain: 'foos')}
  let(:user) {FactoryGirl.create(:user, state: :active, current_stage: :registered, company: company)}
  let(:report) {FactoryGirl.create(:report, report_creator_id: user.id, company_id: company.id, id: 1, name: 'Doc Test Report', report_type: 3, user_id: user.id, meta: {"team_id"=>nil, "location_id"=>nil, "filter_by"=>"all_documents", "sort_by"=>"due_date_desc", "employee_type"=>"all_employee_status"})}
  let(:report2) {FactoryGirl.create(:report, name: 'default', report_creator_id: user.id, company_id: company.id, report_type: 3, user_id: user.id, meta: {"team_id"=>nil, "location_id"=>nil, "filter_by"=>"all_documents", "sort_by"=>"due_date_desc", "employee_type"=>"all_employee_status"})}

  describe 'Associations' do
    it { is_expected.to belong_to(:users).class_name('User').with_foreign_key(:user_id) }
    it { is_expected.to belong_to(:company)}
    it { is_expected.to have_many(:custom_field_reports).dependent(:destroy) }
  end

  describe 'Validation' do
    it 'should Validate that start date is less than end date' do
      report.meta['start_date'] = '15/07/2019'
      report.meta['end_date'] = '15/07/2019'
      expect { report.save! }.to raise_error(ArgumentError, "invalid date")
    end

    it 'should check get report name with time function if report name is not default' do
      expect(report.get_report_name_with_time).not_to eq(nil)
    end
    it 'should check get report name with time function if report name is default' do
      expect(report2.get_report_name_with_time).not_to eq(nil)
    end

    it 'should get default report' do
      report1 = Report.default_report(company, {"date_filter" => Date.today, "filters" => "{}"})
      expect(report1.name).to eq("default")
    end
    it 'should get default report with department and location filter' do
      report1 = Report.default_report(company, {"date_filter" => Date.today, "filters" => "{\"Departments\":{\"Departments\":[1,2]},\"Locations\":{\"Locations\":[5]},\"employment_status\":{\"17\":[24]}}"})
      expect(report1.meta["team_id"]).not_to eq(nil)
      expect(report1.meta["location_id"]).not_to eq(nil)
    end
    it 'should get turnover report' do
      report1 = Report.turnover_report(company, {"date_filter" => Date.today, "filters" => "{}"})
      expect(report1.name).to eq("turnover")
    end
    it 'should get turnover report' do
      report1 = Report.turnover_report(company, {"date_filter" => Date.today, "filters" => "{\"Departments\":{\"Departments\":[1,2]},\"Locations\":{\"Locations\":[5]},\"employment_status\":{\"17\":[24]}}"})
      expect(report1.meta["team_id"]).not_to eq(nil)
      expect(report1.meta["location_id"]).not_to eq(nil)
    end
  end

  describe 'callbacks' do
    context 'should run before and after create callbacks' do
      it 'should assign default user role ids to report' do
        expect(report.user_role_ids.count).to be > 0
      end
    end

    context 'should run before and after save callbacks' do
      it 'should maintain unique values for user role' do
        id_count = report.user_role_ids.count
        report.user_role_ids.push(report.user_role_ids[0])
        report.save
        expect(report.user_role_ids.count).to eq(id_count)
      end
    end
  end
end
