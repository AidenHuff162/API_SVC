require 'rails_helper'

RSpec.describe HrisIntegrationsService::Xero::ParamsBuilder do
  before(:all) do
    @company = FactoryGirl.create(:company, subdomain: 'xero-company')
    @company.profile_templates.destroy_all
    ProfileTemplateCustomFieldConnection.with_deleted.where(profile_template_id: @company.profile_templates.with_deleted.pluck(:id)).delete_all
    @company.profile_templates.with_deleted.delete_all
    @user = FactoryGirl.create(:user, state: :active, current_stage: :registered, company: @company, xero_id: '123')
    @offboarded_user = FactoryGirl.create(:offboarded_user, company: @company)
    @calculation_type = FactoryGirl.create(:calculation_type, name: 'Calculation Type', section: 'personal_info', field_type: 'mcq', company: @company)
    @annual_salary = FactoryGirl.create(:custom_field, name: 'Annual Salary', section: 'personal_info', field_type: 'number', company: @company)
    @hours_per_week = FactoryGirl.create(:custom_field, name: 'Hours Per Week', section: 'personal_info', field_type: 'number', company: @company)
    @rate_per_unit = FactoryGirl.create(:custom_field, name: 'Rate Per Unit', section: 'personal_info', field_type: 'number', company: @company)
    @company.custom_fields.where(name: 'Employment Status').destroy_all
    @xero_employment_status = FactoryGirl.create(:xero_employment_status, name: 'Xero Employment Status', company: @company)
    @xero_employment_status.update(name: 'Employment Status')
    @xero = FactoryGirl.create(:xero_instance, company_id: @company.id)
    @param_builder = HrisIntegrationsService::Xero::ParamsBuilder.new
  end

  describe '#manage mapping of sapling gender options to Xero' do
    it 'maps sapling gender(male) to its xero type - case 1 - success' do
      CustomFieldValue.set_custom_field_value(@user, 'Gender', 'Male')
      result = @param_builder.build_gender_params(@user)
      expect(Hash.from_xml(result)["Employees"]["Employee"]["Gender"]).to eq('M')
    end

    it 'maps sapling gender(female) to its xero type - case 2 - success' do
      CustomFieldValue.set_custom_field_value(@user, 'Gender', 'Female')
      result = @param_builder.build_gender_params(@user)
      expect(Hash.from_xml(result)["Employees"]["Employee"]["Gender"]).to eq('F')
    end

    it 'maps sapling gender(Not Specified) to its xero type - case 3 - success' do
      CustomFieldValue.set_custom_field_value(@user, 'Gender', 'not specified')
      result = @param_builder.build_gender_params(@user)
      expect(Hash.from_xml(result)["Employees"]["Employee"]["Gender"]).to eq('N')
    end

    it 'maps sapling gender(other) to its xero type - case 3 - success' do
      CustomFieldValue.set_custom_field_value(@user, 'Gender', 'other')
      result = @param_builder.build_gender_params(@user)
      expect(Hash.from_xml(result)["Employees"]["Employee"]["Gender"]).to eq('I')
    end
  end

  describe '#manage mapping of sapling employee type to Xero' do
    it 'maps sapling employee type(Full Time) to its xero type - case 1 - success' do
      CustomFieldValue.set_custom_field_value(@user, 'Employment Status', 'Full Time')
      result = @param_builder.build_employment_basis_params(@user)
      expect(result["Employee"]["TaxDeclaration"]["EmploymentBasis"]).to eq('FULLTIME')
    end

    it 'maps sapling employee type(Part Time) to its xero type - case 2 - success' do
      CustomFieldValue.set_custom_field_value(@user, 'Employment Status', 'Part Time')
      result = @param_builder.build_employment_basis_params(@user)
      expect(result["Employee"]["TaxDeclaration"]["EmploymentBasis"]).to eq('PARTTIME')
    end

    it 'maps sapling employee type(Casual) to its xero type - case 3 - success' do
      CustomFieldValue.set_custom_field_value(@user, 'Employment Status', 'casual')
      result = @param_builder.build_employment_basis_params(@user)
      expect(result["Employee"]["TaxDeclaration"]["EmploymentBasis"]).to eq('CASUAL')
    end

    it 'maps sapling employee type(Labour Hire) to its xero type - case 4 - success' do
      CustomFieldValue.set_custom_field_value(@user, 'Employment Status', 'Labour Hire')
      result = @param_builder.build_employment_basis_params(@user)
      expect(result["Employee"]["TaxDeclaration"]["EmploymentBasis"]).to eq('LABOURHIRE')
    end

    it 'maps sapling employee type(super in come stream) to its xero type - case 5 - success' do
      CustomFieldValue.set_custom_field_value(@user, 'Employment Status', 'super in come stream')
      result = @param_builder.build_employment_basis_params(@user)
      expect(result["Employee"]["TaxDeclaration"]["EmploymentBasis"]).to eq('SUPERINCOMESTREAM')
    end
  end

  describe '#manage mapping of sapling calculation type to Xero' do
    it 'maps sapling calculation type(annual salary) to its xero type if annual salary and hours per week are present- case 1 - success' do
      stub_get_employee_earning_lines
      CustomFieldValue.set_custom_field_value(@user, 'Calculation Type', 'annual salary')
      CustomFieldValue.set_custom_field_value(@user, 'Annual Salary', 2000)
      CustomFieldValue.set_custom_field_value(@user, 'Hours Per Week', 40)
      result = @param_builder.build_calculation_type_params(@user, @xero)
      expect(result["Employee"]["PayTemplate"]["EarningsLines"].first["CalculationType"]).to eq('ANNUALSALARY')
      expect(result["Employee"]["PayTemplate"]["EarningsLines"].first["AnnualSalary"]).to eq("2000")
      expect(result["Employee"]["PayTemplate"]["EarningsLines"].first["NumberOfUnitsPerWeek"]).to eq("40")
    end

    it 'maps sapling calculation type(user earning rate) to its xero type if rate per unit is present - case 2 - success' do
      stub_get_employee_earning_lines
      CustomFieldValue.set_custom_field_value(@user, 'Calculation type', 'user earning rate')
      CustomFieldValue.set_custom_field_value(@user, 'Rate Per Unit', 50)
      result = @param_builder.build_calculation_type_params(@user, @xero)
      expect(result["Employee"]["PayTemplate"]["EarningsLines"].first["CalculationType"]).to eq('USEEARNINGSRATE')
    end

    it 'maps sapling calculation type(user earning rate) to its xero type if rate per unit is not present - case 3 - success' do
      stub_get_employee_earning_lines
      CustomFieldValue.set_custom_field_value(@user, 'Calculation type', 'user earning rate')
      result = @param_builder.build_calculation_type_params(@user, @xero)
      expect(result["Employee"]["PayTemplate"]["EarningsLines"].first["CalculationType"]).to eq('USEEARNINGSRATE')
    end

    it 'maps sapling calculation type(enter earning rate) to its xero type if rate per unit is present - case 4 - success' do
      stub_get_employee_earning_lines
      CustomFieldValue.set_custom_field_value(@user, 'Calculation type', 'enter earning rate')
      CustomFieldValue.set_custom_field_value(@user, 'Rate Per Unit', 50)
      result = @param_builder.build_calculation_type_params(@user, @xero)
      expect(result["Employee"]["PayTemplate"]["EarningsLines"].first["CalculationType"]).to eq('ENTEREARNINGSRATE')
    end

    it 'maps sapling calculation type(enter earning rate) to its xero type if rate per unit is not present - case 5 - success' do
      stub_get_employee_earning_lines
      CustomFieldValue.set_custom_field_value(@user, 'Calculation type', 'enter earning rate')
      result = @param_builder.build_calculation_type_params(@user, @xero)
      expect(result["Employee"]["PayTemplate"]["EarningsLines"].first["CalculationType"]).to eq('ENTEREARNINGSRATE')
    end

    it 'should map sapling calculation type(annual salary) to its xero type if earning rate id is not present- case 6 - failure' do
      @xero.stub(:pay_template) {nil}
      CustomFieldValue.set_custom_field_value(@user, 'Calculation type', 'annual salary')
      result = @param_builder.build_calculation_type_params(@user, @xero)
      expect(result["Employee"]["PayTemplate"]).to eq(nil)
    end

    it 'should map sapling calculation type(enter earning rate) to its xero type if earning rate id is not present- case 7 - failure' do
      @xero.stub(:pay_template) {nil}
      CustomFieldValue.set_custom_field_value(@user, 'Calculation type', 'enter earning rate')
      result = @param_builder.build_calculation_type_params(@user, @xero)
      expect(result["Employee"]["PayTemplate"]).to eq(nil)
    end

    it 'should map sapling calculation type(user earning rate) to its xero type if earning rate id is not present- case 8 - failure' do
      @xero.stub(:pay_template) {nil}
      CustomFieldValue.set_custom_field_value(@user, 'Calculation type', 'user earning rate')
      result = @param_builder.build_calculation_type_params(@user, @xero)
      expect(result["Employee"]["PayTemplate"]).to eq(nil)
    end

    it 'should maps sapling calculation type(annual salary) to its xero type if annual salary and hours per week are not present- case 9 - failure' do
      stub_get_employee_earning_lines
      CustomFieldValue.set_custom_field_value(@user, 'Calculation type', 'annual salary')
      result = @param_builder.build_calculation_type_params(@user, @xero)
      expect(result["Employee"]["PayTemplate"]).to eq(nil)
    end
  end

  describe '#manage mapping of sapling terminated options to Xero' do
    it 'maps sapling status(terminated) to its xero type - case 1 - success' do
      result = @param_builder.build_terminated_params(@offboarded_user)
      expect(Hash.from_xml(result)["Employees"]["Employee"]["Status"]).to eq('TERMINATED')
      expect(Hash.from_xml(result)["Employees"]["Employee"]["TerminationDate"]).to eq(@offboarded_user.termination_date)
    end
  end

  describe '#manage mapping of sapling onboard params  to Xero' do
    
    it 'maps sapling name to its xero name - case 1 - success' do
      @result = Hash.from_xml(@param_builder.build_onboard_params(@user, @xero))
      expect(@result["Employees"]["Employee"]["FirstName"]).to eq(@user.first_name)
      expect(@result["Employees"]["Employee"]["LastName"]).to eq(@user.last_name)
    end

    it 'maps sapling title to its xero job title - case 2 - success' do
      @result = Hash.from_xml(@param_builder.build_onboard_params(@user, @xero))
      expect(@result["Employees"]["Employee"]["JobTitle"]).to eq(@user.title)
    end

    it 'maps sapling start date to its xero start date - case 3 - success' do
      @result = Hash.from_xml(@param_builder.build_onboard_params(@user, @xero))
      expect(@result["Employees"]["Employee"]["StartDate"]).to eq(@user.start_date)
    end

    it 'maps sapling personal email to its xero email - case 4 - success' do
      @result = Hash.from_xml(@param_builder.build_onboard_params(@user, @xero))
      expect(@result["Employees"]["Employee"]["Email"]).to eq(@user.personal_email)
    end

    it 'maps sapling status to its xero status - case 4 - success' do
      @result = Hash.from_xml(@param_builder.build_onboard_params(@user, @xero))
      expect(@result["Employees"]["Employee"]["Status"]).to eq('ACTIVE')
    end
  end
end

def stub_get_employee_earning_lines
  stub_request(:get, 'https://api.xero.com/payroll.xro/1.0/Employees/123').
    with( headers: {'Accept' => 'application/json', 'Xero-tenant-id' => @xero.company_code, 'Authorization' => 'Bearer ' + @xero.access_token}).
    to_return(status: 200, body: %Q({"Employees": [{"PayTemplate": {"EarningsLines": []}}]}), headers: {})
end