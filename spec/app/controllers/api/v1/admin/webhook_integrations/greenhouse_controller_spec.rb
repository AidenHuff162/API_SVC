require 'rails_helper'

RSpec.describe Api::V1::Admin::WebhookIntegrations::GreenhouseController, type: :controller do
  let(:company) { create(:company, subdomain: 'greenhouse') }
    
  before do
    allow(controller).to receive(:current_company).and_return(company)
    @params = {:payload=>{:application=>{:id=>42329544002, :opening=>{:opening_id=>"JP-2021-1"}, :credited_to=>{:id=>nil, :name=>"Grace Wang"}, :source=>{:id=>4026780002, :name=>"Specialized Group"}, :candidate=>{:id=>37868370002, :first_name=>"Estefany", :last_name=>"Cerda", :title=>"Enterprise Account Executive", :is_private=>true, :can_email=>true, :external_id=>nil, :phone_numbers=>[], :email_addresses=>[{:value=>"asdf@gmail.com", :type=>"personal"}], :addresses=>[], :educations=>[], :employments=>[], :recruiter=>{:id=>4159493002, :email=>"aaaa@as.com", :employee_id=>nil, :name=>"Kensuke Morimoto"}, :coordinator=>{:id=>4319304002, :email=>"aaa@bbb.com", :employee_id=>nil, :name=>"Alice Chu"}, :attachments=>[{:filename=>"Kentaro_Wada_-_Offer_Packet_2020-01-13_(Private).pdf", :url=>"", :type=>"offer_packet"}, {:filename=>"Kentaro_Wada_-_CircleCI_GK_-_Employment_Agreement_February_2020_Kentaro_Wada_Signed.pdf", :url=>"", :type=>"other"}, {:filename=>"(1212)Enterprise Account Manager kentaro wada.docx", :url=>"", :type=>"resume"}], :custom_fields=>{:base_salary=>{:name=>"Base Salary", :type=>"number", :value=>"6902268.0"}, :"company_candidate_1575574888.3818765"=>{:name=>"Company", :type=>"single_select", :value=>"CircleCI G.K"}, :department=>{:name=>"Department", :type=>"single_select", :value=>["Revenue"]}, :"direct_reports_candidate_1578521942.9387465"=>{:name=>"Direct Reports", :type=>"single_select", :value=>"Yes"}, :equity_level=>{:name=>"Equity Level", :type=>"single_select", :value=>"2"}, :interviewer_first_name=>{:name=>"Interviewer First Name", :type=>"user", :value=>{:user_id=>nil, :name=>nil, :email=>nil, :employee_id=>nil}}, :interviewers_email_address=>{:name=>"Interviewers Email Address", :type=>"user", :value=>{:user_id=>nil, :name=>nil, :email=>nil, :employee_id=>nil}}, :interviewers_full_name=>{:name=>"Interviewers Full Name", :type=>"user", :value=>{:user_id=>nil, :name=>nil, :email=>nil, :employee_id=>nil}}, :mobile_phone_1=>{:name=>"Mobile Phone", :type=>"short_text", :value=>nil}, :office_location=>{:name=>"Office Location", :type=>"long_text", :value=>"Tokyo"}, :onboarding_location=>{:name=>"Onboarding Location", :type=>"long_text", :value=>"Denver one week"}, :reports_to=>{:name=>"Reports To", :type=>"short_text", :value=>"Tess Rickert"}, :"team_candidate_1575579970.3388233"=>{:name=>"Team", :type=>"single_select", :value=>"Account Executive"}, :type=>{:name=>"Type", :type=>"single_select", :value=>"Full Time"}, :variable_comp=>{:name=>"Variable Comp", :type=>"number", :value=>"0.0"}}}, :job=>{:id=>4212551002, :name=>"Japan Account Executive", :open_date=>"2019-11-13T04:02:53.416Z", :close_date=>"2020-01-14T02:39:42.025Z", :requisition_id=>"JP-AE", :departments=>[{:id=>4017535002, :name=>"Japan", :external_id=>nil}], :offices=>[{:id=>4005765002, :name=>"Japan", :location=>", Japan", :external_id=>nil}], :custom_fields=>{:employment_type=>{:name=>"Employment Type", :type=>"single_select", :value=>"Full-time"}, :hiring_manager=>{:name=>"Hiring Manager", :type=>"user", :value=>{:user_id=>4159493002, :name=>"Tess Rickert", :email=>"tess123@circleci.com", :employee_id=>nil}}}}, :jobs=>[{:id=>4212551002, :name=>"Japan Account Executive", :requisition_id=>"JP-AE", :opened_at=>"2019-11-13T04:02:53.416Z", :closed_at=>"2020-01-14T02:39:42.025Z", :departments=>[{:id=>4017535002, :name=>"Japan", :external_id=>nil}], :offices=>[{:id=>4005765002, :name=>"Japan", :location=>", Japan", :external_id=>nil}], :custom_fields=>{:employment_type=>{:name=>"Employment Type", :type=>"single_select", :value=>"Full-time"}, :hiring_manager=>{:name=>"Hiring Manager", :type=>"user", :value=>{:user_id=>4159493002, :name=>"Tess Rickert", :email=>"te123ss@circleci.com", :employee_id=>nil}}}}], :custom_fields=>{}, :offer=>{:id=>4523462002, :version=>1, :created_at=>"2020-01-14T02:39:41Z", :sent_at=>nil, :resolved_at=>"2020-01-14T02:39:41Z", :starts_at=>"2020-02-03", :custom_fields=>{:address=>{:name=>"Address", :type=>"long_text", :value=>nil}, :employment_type=>{:name=>"Employment Type", :type=>"single_select", :value=>"Full-time"}, :equity=>{:name=>"Equity", :type=>"short_text", :value=>"7421"}, :external_job_name=>{:name=>"External Job Name", :type=>"short_text", :value=>"Account Executive"}, :fixed_overtime=>{:name=>"Fixed Overtime", :type=>"currency", :value=>{:unit=>"JPY", :amount=>"1597740.0"}}, :guarantee_months=>{:name=>"Guarantee Months", :type=>"long_text", :value=>nil}, :japan_work_location=>{:name=>"Japan Work Location", :type=>"multi_select", :value=>[]}, :job_responsibilities=>{:name=>"Job Responsibilities", :type=>"long_text", :value=>nil}, :monthly_salary=>{:name=>"Monthly Salary", :type=>"currency", :value=>{:unit=>nil, :amount=>"0.0"}}, :payroll_job=>{:name=>"payroll_job", :type=>"single_select", :value=>"Base Salary"}, :performance_bonus=>{:name=>"Performance Bonus", :type=>"long_text", :value=>nil}, :"salary_offer_1544044882.3406332"=>{:name=>"Salary", :type=>"currency", :value=>{:unit=>"JPY", :amount=>"6902268.0"}}, :semi_monthly=>{:name=>"Semi Monthly", :type=>"short_text", :value=>nil}, :variable=>{:name=>"Variable", :type=>"short_text", :value=>nil}}}}}}
  end

  describe 'post #create' do
    context 'if current company is not present' do
      it 'should return ok status and true' do
        allow(controller).to receive(:current_company).and_return(nil)
        post :create, params: {greenhouse: @params}, format: :json
        expect(response.status).to eq(200)
        expect(response.body).to eq("true")
      end
    end

    context 'if current company is present' do
      it 'should return ok status and true' do
        post :create, params: {greenhouse: @params}, format: :json
        expect(response.status).to eq(200)
        expect(response.body).to eq("true")
      end

      it 'should create sucess webhook if params are valid' do
        post :create, params: {greenhouse: @params}, format: :json
      end
  
      it 'should create failed webhook if there is some exception in code' do
        company.prefrences= nil
        post :create, params: {greenhouse: @params}, format: :json
      end
      
      it 'should update is_recruitment_system_integrated if params are valid' do
        post :create, params: {greenhouse: @params}, format: :json
        expect(company.reload.is_recruitment_system_integrated).to eq(true)
      end

      it 'should update is_recruitment_system_integrated if params are not valid' do
        post :create, format: :json
        expect(company.reload.is_recruitment_system_integrated).to eq(true)
      end
    end
  end

  describe 'post #mail_parser' do
    context 'if current company is not present' do
      it 'should return ok status and true' do
        allow(controller).to receive(:current_company).and_return(nil)
        post :mail_parser, params: {greenhouse: @params}, format: :json
        expect(response.status).to eq(200)
        expect(response.body).to eq("true")
      end
    end

    context 'if current company is present' do
      it 'should return ok status and true' do
        post :mail_parser, params: {greenhouse: @params}, format: :json
        expect(response.status).to eq(200)
        expect(response.body).to eq("true")
      end

      it 'should create sucess webhook if params are valid' do
        post :mail_parser, params: {greenhouse: @params}, format: :json
      end
  
      it 'should create failed webhook if there is some exception in code' do
        company.prefrences= nil
        post :mail_parser, params: {greenhouse: @params}, format: :json
      end
      
      it 'should update is_recruitment_system_integrated if params are valid' do
        post :mail_parser, params: {greenhouse: @params}, format: :json
        expect(company.reload.is_recruitment_system_integrated).to eq(true)
      end

      it 'should update is_recruitment_system_integrated if params are not valid' do
        post :mail_parser, format: :json
        expect(company.reload.is_recruitment_system_integrated).to eq(true)
      end
    end
  end

end
 