require 'rails_helper'

RSpec.describe Api::V1::Admin::ReportsController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:user1) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:user2) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:user3) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:user4) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:valid_session) { {} }
  let(:workstream) { create(:workstream, company: company) }
  let(:workstream1) { create(:workstream, company: company) }
  let(:task) { create(:task, workstream: workstream) }
  let(:task1) { create(:task, workstream: workstream) }
  let(:task2) { create(:task, workstream: workstream1) }
  let(:task3) { create(:task, workstream: workstream1) }
  let(:report) { create(:report, id: 1, company_id: company.id, name: 'Doc Test Report', report_type: 'document', user_id: user.id, meta: {"team_id": nil, "location_id": nil, "filter_by": "all_documents", "sort_by": "due_date_desc", "employee_type": "all_employee_status"})}
  let(:permanent_fields) { [{"id": "fn", "position": 1}, {"id": "ln", "position": 2}, {"id": "ce", "position": 3}, {"id": "sd", "position": 4}, {"id": "jt", "position": 5}, {"id": "pe", "position": 6}, {"id": "dpt", "position": 7}, {"id": "loc", "position": 8}, {"id": "man", "position": 9}] }
  let(:report_meta) { {"team_id": nil, "location_id": nil, "filter_by": "all_employees", "sort_by": "start_date_asc", "employee_type": "all_employee_status", "date_range_type": 5, "start_date": nil, "end_date": nil, "only_managers": true, "other_section": [{"id": "ui", "name": "User ID", "position": 0},{"id": "mge", "name": "Manager Email", "position": 10}]} }

  before do
    allow(controller).to receive(:current_user).and_return(user1)
    allow(controller).to receive(:current_user).and_return(user2)
    allow(controller).to receive(:current_user).and_return(user3)
    allow(controller).to receive(:current_user).and_return(user4)
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "POST #create" do
    it 'should not create report if name is not present' do
      post :create, params: { company_id: company.id, name: '',user_id: user.id }, format: :json
      expect(response.message).to eq('Unprocessable Entity')
    end

    it 'should create report if name is present' do
      post :create, params: { company_id: company.id, name: 'Test Report',user_id: user.id, permanent_fields: permanent_fields, meta: report_meta }, format: :json
      expect(response.message).to eq('Created')
    end
  end

  describe "GET #get_reports" do
    it "should get all user reports" do
      create(:report, company: user.company, report_type: 'user')
      create(:report, company: user.company, report_type: 'user')
      create(:report, company: user.company, report_type: 'time_off')
      get :get_reports, params: { format: :json, length: 10, report_type: 'user', start: 0 , columns: {"0": {"data": "name", "name": "", "searchable": "true", "orderable": "true", "search": {"value": "", "regex": "false"}}, "1": {"data": "created_at", "name": "", "searchable": "true", "orderable": "true", "search": {"value": "", "regex": "false"}}, "2": {"data": "", "name": "", "searchable": "true", "orderable": "false", "search": {"value": "", "regex": "false"}}, "3": {"data": "", "name": "", "searchable": "true", "orderable": "true", "search": {"value": "", "regex": "false"}}, "4": {"data": "", "name": "", "searchable": "true", "orderable": "false", "search": {"value": "", "regex": "false"}}}, order: {"0": {"column": "0", "dir": "asc"}} }
      expect(JSON.parse(response.body)['data'].length).to eq(2)
      expect(response.status).to eq(200)
    end

    it "should get all time_off reports" do
      create(:report, company: user.company, report_type: 'user')
      create(:report, company: user.company, report_type: 'user')
      create(:report, company: user.company, report_type: 'time_off')
      get :get_reports, params: { format: :json, length: 10, report_type: 'time_off', start: 0 , columns: {"0": {"data": "name", "name": "", "searchable": "true", "orderable": "true", "search": {"value": "", "regex": "false"}}, "1": {"data": "created_at", "name": "", "searchable": "true", "orderable": "true", "search": {"value": "", "regex": "false"}}, "2": {"data": "", "name": "", "searchable": "true", "orderable": "false", "search": {"value": "", "regex": "false"}}, "3": {"data": "", "name": "", "searchable": "true", "orderable": "true", "search": {"value": "", "regex": "false"}}, "4": {"data": "", "name": "", "searchable": "true", "orderable": "false", "search": {"value": "", "regex": "false"}}}, order: {"0": {"column": "0", "dir": "asc"}} }
      expect(JSON.parse(response.body)['data'].length).to eq(1)
      expect(response.status).to eq(200)
    end

    it "should get first 2 reports when length is 2 and starting index is 0 based on pagination" do
      create(:report, company: user.company, report_type: 'user')
      create(:report, company: user.company, report_type: 'user')
      create(:report, company: user.company, report_type: 'time_off')
      get :get_reports, params: { format: :json, length: 2, report_type: 'user', start: 0 , columns: {"0": {"data": "name", "name": "", "searchable": "true", "orderable": "true", "search": {"value": "", "regex": "false"}}, "1": {"data": "created_at", "name": "", "searchable": "true", "orderable": "true", "search": {"value": "", "regex": "false"}}, "2": {"data": "", "name": "", "searchable": "true", "orderable": "false", "search": {"value": "", "regex": "false"}}, "3": {"data": "", "name": "", "searchable": "true", "orderable": "true", "search": {"value": "", "regex": "false"}}, "4": {"data": "", "name": "", "searchable": "true", "orderable": "false", "search": {"value": "", "regex": "false"}}}, order: {"0": {"column": "0", "dir": "asc"}} }
      expect(JSON.parse(response.body)['data'].length).to eq(2)
      expect(response.status).to eq(200)
    end

    it "should get first 3 reports when length is 3 and starting index is 0 based on pagination" do
      create(:report, company: user.company, report_type: 'user')
      create(:report, company: user.company, report_type: 'user')
      create(:report, company: user.company, report_type: 'user')
      create(:report, company: user.company, report_type: 'user')
      create(:report, company: user.company, report_type: 'time_off')
      get :get_reports, params: { format: :json, length: 3, report_type: 'user', start: 0 , columns: {"0": {"data": "name", "name": "", "searchable": "true", "orderable": "true", "search": {"value": "", "regex": "false"}}, "1": {"data": "created_at", "name": "", "searchable": "true", "orderable": "true", "search": {"value": "", "regex": "false"}}, "2": {"data": "", "name": "", "searchable": "true", "orderable": "false", "search": {"value": "", "regex": "false"}}, "3": {"data": "", "name": "", "searchable": "true", "orderable": "true", "search": {"value": "", "regex": "false"}}, "4": {"data": "", "name": "", "searchable": "true", "orderable": "false", "search": {"value": "", "regex": "false"}}}, order: {"0": {"column": "0", "dir": "asc"}} }
      expect(JSON.parse(response.body)['data'].length).to eq(3)
      expect(response.status).to eq(200)
    end

    it "should get all only user reports with names similar to search value" do
      create(:report, company: user.company, report_type: 'user', name: 'asdf')
      create(:report, company: user.company, report_type: 'user', name: 'user report 2')
      create(:report, company: user.company, report_type: 'user', name: 'user report 3')
      get :get_reports, params: { format: :json, length: 10, report_type: 'user', start: 0 , columns: {"0": {"data": "name", "name": "", "searchable": "true", "orderable": "true", "search": {"value": "", "regex": "false"}}, "1": {"data": "created_at", "name": "", "searchable": "true", "orderable": "true", "search": {"value": "", "regex": "false"}}, "2": {"data": "", "name": "", "searchable": "true", "orderable": "false", "search": {"value": "", "regex": "false"}}, "3": {"data": "", "name": "", "searchable": "true", "orderable": "true", "search": {"value": "", "regex": "false"}}, "4": {"data": "", "name": "", "searchable": "true", "orderable": "false", "search": {"value": "", "regex": "false"}}}, order: {"0": {"column": "0", "dir": "asc"}}, "search": {"value": "report","regex": "false" } }
      expect(JSON.parse(response.body)['data'].length).to eq(2)
      expect(response.status).to eq(200)
    end
  end

  describe "GET #report_csv" do
    it "should get a user report with file content and name" do
      report = create(:report, id: 1, company: user.company, report_type: 'user',
      permanent_fields:
      [{"id": "sd", "position": 1},
       {"id": "fn", "position": 2}],
      meta:
      {"team_id": nil,
       "location_id": nil,
       "filter_by": "all_employees",
       "sort_by": "start_date_asc",
       "employee_type": "all_employee_status",
       "date_range_type": 5,
       "start_date": nil,
       "end_date": nil,
       "only_managers": true,
       "other_section": 
        [{"id": "ui", "name": "User ID", "position": 0},
         {"id": "mge", "name": "Manager Email", "position": 10}]})

      get :report_csv, params: { format: :json, report_id: report.id }
      expect(JSON.parse(response.body).length).to eq(1)
      expect(response.status).to eq(200)
    end
  end

  describe "GET #index" do
    it "should get the reports" do
      create(:report, company: user.company)
      create(:report, company: user.company)

      get :index, params: valid_session, format: :json
      expect(JSON.parse(response.body).length).to eq(2)
    end

    it "should only get the reports of current company" do
      create(:report, company: user.company)
      create(:report, company: user.company)
      create(:report, company: create(:company, subdomain: 'boo'))

      get :index, params: valid_session, format: :json
      expect(JSON.parse(response.body).length).to eq(2)
      expect(response.status).to eq(200)
    end
  end

  describe "POST #update" do
    it "should update name of report" do
      create(:report, company: user.company, report_type: 'user', name: 'report1', id: 1, permanent_fields: permanent_fields, meta: report_meta)
      post :update, params: { format: :json, id: 1, name: 'updated report' }
      expect(JSON.parse(response.body)["name"]).to eq("updated report")
      expect(response.status).to eq(201)
    end
  end

  describe "DELETE #destroy" do
    it "should destroy a report based on id" do
      report = create(:report, company: user.company, report_type: 'user', name: 'report1')
      delete :destroy, params: { id: report.id }, format: :json
      expect(response.status).to eq(204)
      expect(Report.find_by(id: report.id)).to eq(nil)
    end

    it "should delete custom field reports on report deletion" do
      report = create(:report, company: user.company, report_type: 'user', name: 'report1')
      custom_field_reports = report.custom_field_reports
      delete :destroy, params: { id: report.id }, format: :json
      expect(CustomFieldReport.find_by(id: report.custom_field_reports.ids)).to eq(nil)
      expect(response.status).to eq(204)
    end
  end

  describe "POST #create" do
    it 'should create time off report' do
      post :create, params: { company_id: company.id, name: 'Timeoff Test Report', report_type: 'time_off', user_id: user.id, permanent_fields: permanent_fields, meta: {"team_id": nil, "location_id": nil, "filter_by": "active_only", "employee_type": "all_employee_status", "date_range_type": 5, "start_date": nil,"end_date": nil,"pto_policy": 1, "include_unapproved_timeoff": true, "other_section": [{"id": "ui", "name": "User ID", "position": 0},{"id": "mge", "name": "Manager Email", "position": 10}]} }, format: :json
      expect(response.message).to eq('Created')
    end

    it 'should create workflow report' do
      post :create, params: { company_id: company.id, name: 'Test Report', report_type: 'workflow', user_id: user.id, meta: {"team_id": nil, "location_id": nil, "filter_by": "overdue", "sort_by": "due_date_desc", "employee_type": "all_employee_status", "date_range_type": 5,"start_date": nil,"end_date": nil,"only_managers": false,"tasks_ids": [task.id, task1.id, task2.id, task3.id], "tasks_positions": [0,1,2,3], "workflow": true, "other_section": [{"id": "ui", "name": "User ID", "position": 0},{"id": "mge", "name": "Manager Email", "position": 10}]} }, format: :json
      expect(response.message).to eq('Created')
    end

    it 'should create document report' do
      post :create, params: { company_id: company.id, name: 'Doc Test Report', report_type: 'document', user_id: user.id, meta: {"team_id": nil, "location_id": nil, "filter_by": "all_documents", "sort_by": "due_date_desc", "employee_type": "all_employee_status"} }, format: :json
      expect(response.message).to eq('Created')
    end
  end

  describe "POST #update" do
    it "should update tasks and task positions of workflow report" do
      create(:report, id: 1, company_id: company.id, name: 'Test Report', report_type: 'workflow', user_id: user.id, meta: {"team_id": nil, "location_id": nil, "filter_by": "overdue", "sort_by": "due_date_desc", "employee_type": "all_employee_status", "date_range_type": 5,"start_date": nil,"end_date": nil,"only_managers": false,"tasks_ids": [task.id, task1.id, task2.id, task3.id], "tasks_positions": [0,1,2,3],"workflow": true})
      post :update, params: { format: :json, id: 1, name: 'Testo Report', meta: {"team_id": nil, "location_id": nil, "filter_by": "overdue", "sort_by": "due_date_desc", "employee_type": "all_employee_status", "date_range_type": 5,"start_date": nil,"end_date": nil,"only_managers": false,"tasks_ids": [task1.id, task.id], "tasks_positions": [1,0],"workflow": true}}
      expect(JSON.parse(response.body)["meta"]["tasks_ids"].count).to eq(2)
      expect(response.status).to eq(201)
    end

    it "should update filter of time off report" do
      create(:report, id: 1, company_id: company.id, name: 'Timeoff Test Report', report_type: 'time_off', user_id: user.id, permanent_fields: permanent_fields, meta: {"team_id": nil, "location_id": nil, "filter_by": "active_only", "employee_type": "all_employee_status", "date_range_type": 5, "start_date": nil,"end_date": nil,"pto_policy": 1, "include_unapproved_timeoff": true, "other_section": [{"id": "ui", "name": "User ID", "position": 0},{"id": "mge", "name": "Manager Email", "position": 10}]})
      post :update, params: {id: 1, company_id: company.id, name: 'Timeoff Test Report', report_type: 'time_off', user_id: user.id, permanent_fields: permanent_fields, meta: {"team_id": nil, "location_id": nil, "filter_by": "active_only", "employee_type": "all_employee_status", "date_range_type": 5, "start_date": nil,"end_date": nil,"pto_policy": 2, "include_unapproved_timeoff": true, "other_section": [{"id": "ui", "name": "User ID", "position": 0},{"id": "mge", "name": "Manager Email", "position": 10}]}}, as: :json
      expect(JSON.parse(response.body)["meta"]["pto_policy"]).to eq(2)
      expect(response.status).to eq(201)
    end

    it "should update filter of workflow report" do
      create(:report, id: 1, company_id: company.id, name: 'Test Report', report_type: 'workflow', user_id: user.id, meta: {"team_id": nil, "location_id": nil, "filter_by": "overdue", "sort_by": "due_date_desc", "employee_type": "all_employee_status", "date_range_type": 5,"start_date": nil,"end_date": nil,"only_managers": false,"tasks_ids": [task.id, task1.id, task2.id, task3.id], "tasks_positions": [0,1,2,3],"workflow": true})
      post :update, params: { format: :json, id: 1, meta: {"team_id": nil, "location_id": nil, "filter_by": "completed", "sort_by": "due_date_desc", "employee_type": "all_employee_status", "date_range_type": 5,"start_date": nil,"end_date": nil,"only_managers": false,"tasks_ids": [task1.id, task.id], "tasks_positions": [1,0],"workflow": true}}
      expect(JSON.parse(response.body)["meta"]["filter_by"]).to eq("completed")
      expect(response.status).to eq(201)
    end

    it "should update filter of document report" do
      create(:report, id: 1, company_id: company.id, name: 'Doc Test Report', report_type: 'document', user_id: user.id, meta: {"team_id": nil, "location_id": nil, "filter_by": "all_documents", "sort_by": "due_date_desc", "employee_type": "all_employee_status"})
      post :update, params: { format: :json, id: 1, meta: {"team_id": nil, "location_id": nil, "filter_by": "in_progress_docs", "sort_by": "due_date_desc", "employee_type": "all_employee_status"}}
      expect(JSON.parse(response.body)["meta"]["filter_by"]).to eq("in_progress_docs")
      expect(response.status).to eq(201)
    end
  end

  describe "DELETE #destroy" do
    it "should destroy a timeoff report based on id" do
      report = create(:report, company: user.company, report_type: 'time_off', name: 'report1')
      delete :destroy, params: { id: report.id }, format: :json
      expect(response.status).to eq(204)
      expect(Report.find_by(id: report.id)).to eq(nil)
    end

    it "should destroy a workflow report based on id" do
      report = create(:report, company: user.company, report_type: 'workflow', name: 'report1')
      delete :destroy, params: { id: report.id }, format: :json
      expect(response.status).to eq(204)
      expect(Report.find_by(id: report.id)).to eq(nil)
    end

    it "should destroy a document report based on id" do
      report = create(:report, company: user.company, report_type: 'document', name: 'report1')
      delete :destroy, params: { id: report.id }, format: :json
      expect(response.status).to eq(204)
      expect(Report.find_by(id: report.id)).to eq(nil)
    end
  end

  describe "POST #duplicate" do
    it "should create duplicate report" do
      post :duplicate, params: { format: :json, id: report.id}
      expect(JSON.parse(response.body)["name"]).to eq("Copy of " + report.name)
      expect(response.message).to eq('Created')
    end
  end

  describe "POST #last_viewed" do
    it "should update last viewed of report" do
      post :duplicate, params: { format: :json, id: report.id}
      expect(response.status).to eq(201)
    end
  end

  describe "GET #show_with_user_roles" do
    it "should show with user roles of report" do
      get :show_with_user_roles, params: { format: :json, id: report.id}
      expect(response.status).to eq(200)
    end
  end

  describe "GET #report_csv" do
    it "should get a user report with file content and name" do
      report1 = create(:report, id: 6, name: "Simple Report",
        meta:
        {"team_id": nil,
         "location_id": nil,
         "filter_by": "active_only",
         "sort_by": "start_date_desc",
         "employee_type": "all_employee_status",
         "date_range_type": 5,
         "start_date": nil,
         "end_date": nil,
         "only_managers": false,
         "other_section": {}},
        permanent_fields: [{"id": "fn", "position": 0}, {"id": "ln", "position": 1}],
        user_id: user1.id,
        company_id: company.id,
        gsheet_url: nil,
        user_role_ids: ["1"],
        report_type: 'user',
        custom_tables: [{"name": "haaasasa", "enabled_history": false, "position": 2, "section": "haaasasa"}])

      get :report_csv, params: { format: :json , report_id: report1.id}
      expect(response.status).to eq(200)
    end
  end
end
