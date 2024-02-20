class HrisIntegrationsService::Xero::ParamsBuilder
  delegate :get_state_abbreviation, :get_gender_code, :get_employee_type, 
    :get_residency_status_type, :getStatus, :get_calculation_type, 
    :validate_tfn, :annual_units, :get_salary, :get_termination_reason, to: :helper_service
  
  def build_onboard_params(user, xero)  
    status = getStatus(user)
    address = user.get_custom_field_value_text('Home Address', true) || {} rescue {}
    gender_code = get_gender_code(user.get_custom_field_value_text('Gender')) rescue nil
    mobile_phone = user.get_custom_field_value_text('Mobile Phone Number')
    home_phone = user.get_custom_field_value_text('Home Phone Number')
    title = user.get_custom_field_value_text('Title')
    middle_name = user.get_custom_field_value_text('Middle Name')
    
    data = { "Employee" => 
            { "FirstName" => user.first_name, 
              "LastName" => user.last_name, 
              "DateOfBirth" => user.get_custom_field_value_text('Date of Birth'), 
              "HomeAddress"=>
                { "AddressLine1"=> address[:line1],
                  "AddressLine2"=> address[:line2], 
                  "City"=> address[:city], 
                  "Region"=> get_state_abbreviation(address[:state]), 
                  "PostalCode"=> address[:zip], 
                  "Country"=> address[:country]
                }, 
                "Status"=> status, 
                "StartDate"=> user.start_date, 
                "JobTitle"=> user.title, 
                "Email"=> user.personal_email,
              }
            }
   
    data["Employee"]["MiddleNames"] = middle_name if middle_name.present?
    data["Employee"]["PayrollCalendarID"] = xero.payroll_calendar if xero.payroll_calendar.present?
    group = xero.integration_inventory.integration_configurations.find_by(field_name: 'Employee Group')&.dropdown_options&.find{|group| group['value'] == xero.employee_group}
    data["Employee"]["EmployeeGroupName"] = group['label'] if group.present? && group['label']
    data["Employee"]["Title"] = title if title.present?
    data["Employee"]["Gender"] = gender_code if gender_code.present?
    data["Employee"]["Mobile"] = mobile_phone if mobile_phone.present?
    data["Employee"]["Phone"] = home_phone if home_phone.present?

    data['Employee']['EmployeeGroupName'] = (user.get_custom_field_value_text('Cost Center') rescue nil) if user.company.subdomain == 'estimateone'
    data = build_bank_detail_params(user, data)
    data = build_calculation_type_params(user, xero, data)
    data = build_employment_basis_params(user, data)
    return data.to_xml(root: "Employees")
  end

  def build_bank_detail_params(user, params=nil)
    params ||= {'Employee' => { 'EmployeeID' => user.xero_id } }
    account_detail_hash = get_account_detail_hash(user)
    params['Employee'].merge!({ 'BankAccounts' => [account_detail_hash] }) if account_detail_hash
    params
  end

  def get_account_detail_hash(user)
    acct_name = user.get_custom_field_value_text('Account Name')
    acct_number = user.get_custom_field_value_text('Account Number')
    bsb_code = user.get_custom_field_value_text('BSB/Sort Code')
    bank_name = user.company.subdomain == 'estimateone' ? 'EstimateOne Salary' : user.get_custom_field_value_text('Bank Name')
    return unless [acct_name, acct_number, bank_name, bsb_code&.length == 6].all?
    {
      'AccountName' => acct_name,
      'AccountNumber' => acct_number,
      'BSB' => bsb_code,
      'Remainder' => true,
      'StatementText' => bank_name
    }
  end

  def build_name_params(user)
    { "Employee" => { 
        "FirstName" => user.first_name, 
        "LastName" => user.last_name, 
        "EmployeeID" => user.xero_id 
      } 
    }.to_xml(root: "Employees")
  end

  def build_date_of_birth_params(user)
    { "Employee" => { 
        "DateOfBirth" => user.get_custom_field_value_text('Date of Birth'), 
        "EmployeeID" => user.xero_id, 
      } 
    }.to_xml(root: "Employees")
  end

  def build_home_address_params(user)
    address = user.get_custom_field_value_text('Home Address', true) rescue {}
    { "Employee" => { 
        "HomeAddress"=> { "AddressLine1"=> address[:line1], 
        "AddressLine2"=> address[:line2],
        "City"=> address[:city], 
        "Region"=> get_state_abbreviation(address[:state]), 
        "PostalCode"=> address[:zip], 
        "Country"=> address[:country]
        },
      "EmployeeID" => user.xero_id, 
      } 
    }.to_xml(root: "Employees")
  end

  def build_job_title_params(user)
    { "Employee" => { 
        "JobTitle" => user.title, 
        "EmployeeID" => user.xero_id, 
      } 
    }.to_xml(root: "Employees")
  end

  def build_email_params(user)
    { "Employee" => { 
        "Email" => user.personal_email, 
        "EmployeeID" => user.xero_id, 
      } 
    }.to_xml(root: "Employees")
  end

  def build_start_date_params(user)
    { "Employee" => { 
        "StartDate" => user.start_date, 
        "EmployeeID" => user.xero_id, 
      } 
    }.to_xml(root: "Employees")
  end

  def build_title_params(user)
    { "Employee" => { 
        "Title" => user.get_custom_field_value_text('Title'), 
        "EmployeeID" => user.xero_id, 
      } 
    }.to_xml(root: "Employees")
  end

  def build_gender_params(user)
    { "Employee" => { 
        "Gender" => get_gender_code(user.get_custom_field_value_text('Gender')), 
        "EmployeeID" => user.xero_id, 
      } 
    }.to_xml(root: "Employees")
  end
  
  def build_mobile_params(user)
    { "Employee" => { 
        "Mobile" => user.get_custom_field_value_text('Mobile Phone Number'), 
        "EmployeeID" => user.xero_id, 
        } 
    }.to_xml(root: "Employees")
  end

  def build_phone_params(user)
    { "Employee" => { 
        "Phone" => user.get_custom_field_value_text('Home Phone Number'), 
        "EmployeeID" => user.xero_id, 
      } 
    }.to_xml(root: "Employees")
  end

  def build_terminated_params(user)
    { "Employee" => { 
        "TerminationDate" => user.reload.termination_date,
        "Status" => getStatus(user),
        "TerminationReason" => get_termination_reason(user.get_custom_field_value_text('Termination Reason')),
        "EmployeeID" => user.xero_id, 
      } 
    }.to_xml(root: "Employees")
  end  

  def build_middle_name_params(user)
    { "Employee" => { 
        "MiddleNames" => user.get_custom_field_value_text('Middle Name'), 
        "EmployeeID" => user.xero_id, 
      } 
    }.to_xml(root: "Employees")
  end  
  
  def build_employment_basis_params(user, params=nil)
    unless params
      params = {"Employee" => {"EmployeeID" => user.xero_id}}
    end
    
    employee_type = get_employee_type(user.employee_type_field_option&.option) rescue nil 
    
    if employee_type.present?
      tfn_number = user.get_custom_field_value_text('Tax File Number')
      residency_status = get_residency_status_type(user.get_custom_field_value_text('Residency Status')) rescue nil
      
      params["Employee"].merge!({"TaxDeclaration"=>{"EmploymentBasis"=>employee_type}})
      params["Employee"]["TaxDeclaration"]["TaxFileNumber"] = tfn_number&.gsub(' ', '') if tfn_number.present? rescue nil
      params["Employee"]["TaxDeclaration"]["ResidencyStatus"] = residency_status if residency_status.present?
    end
    
    params
  end

  def fetch_existing_earning_lines(user)
    response = HrisIntegrationsService::Xero::HumanResource.new(user.company, nil, user.id).fetch_user(user)
    
    response['Employees'][0]['PayTemplate']['EarningsLines'] rescue []
  end

  def build_calculation_type_params(user, xero, params=nil)
    unless params
      params = {"Employee" => {"EmployeeID" => user.xero_id}}
    end
    calculation_type = get_calculation_type(user.get_custom_field_value_text('Calculation Type')) rescue nil

    if calculation_type.present? && xero.pay_template.present?
        annual_salary = get_salary(user)
        hours_per_week = user.get_custom_field_value_text('Hours Per Week')
        hours_per_week&.gsub!(',','') if hours_per_week&.include?(',')
        rate_per_unit = user.get_custom_field_value_text('Rate Per Unit') 
        rate_per_unit&.gsub!(',','') if rate_per_unit&.include?(',')
      
      if calculation_type == "ANNUALSALARY" && annual_salary.present? && hours_per_week.present?
        data = {"CalculationType"=>calculation_type, "EarningsRateID"=> xero.pay_template, "AnnualSalary"=> annual_salary, "NumberOfUnitsPerWeek" => hours_per_week }
        
        params["Employee"].merge!({ "PayTemplate"=>{"EarningsLines"=> [data] }})
      end
      
      if (calculation_type == "ENTEREARNINGSRATE" || calculation_type == "USEEARNINGSRATE") 
        data = {"CalculationType"=>calculation_type, "EarningsRateID"=> xero.pay_template }
        data["RatePerUnit"] = rate_per_unit if rate_per_unit.present?

        params["Employee"].merge!({ "PayTemplate"=>{"EarningsLines"=> [data] }})
      end
      
      existing_earning_lines = fetch_existing_earning_lines(user)
      existing_earning_lines.each do |leave_line|
        next if  xero.pay_template == leave_line['EarningsRateID']
        params["Employee"]["PayTemplate"]["EarningsLines"].push(leave_line)
      end
    end
    
    
    params
  end

  def build_leave_type_params(policy, leave_types)
    params = nil
    if leave_types.present?
      leave_types.map { |e| e.delete("UpdatedDateUTC")  }
      params = { "LeaveTypes" =>
        leave_types.push(
          { 
            "Name" => policy.name, 
            "TypeOfUnits" => policy.accrual_rate_unit, 
            "IsPaidLeave" => policy.is_paid_leave.to_s, 
            "ShowOnPayslip" => policy.show_balance_on_pay_slip.to_s
          }
        )
      }
    else
      params = { "LeaveTypes" => 
        { "LeaveType" =>
          {
            "Name" => policy.name, 
            "TypeOfUnits" => policy.accrual_rate_unit, 
            "IsPaidLeave"=> policy.is_paid_leave.to_s, 
            "ShowOnPayslip"=> policy.show_balance_on_pay_slip.to_s 
          }
        }
      }
    end
    params.to_xml(root: "PayItems")
  end

  def build_leave_application_params(user, pto_request, leave_periods)
    { 
      "EmployeeID" => user.xero_id, 
      "LeaveTypeID" => pto_request.pto_policy.xero_leave_type_id, 
      "Title" => pto_request.pto_policy.name, 
      "StartDate" => pto_request.begin_date.to_s, 
      "EndDate" => pto_request.get_end_date.to_s,
      "LeavePeriods" => leave_periods
    }.to_xml(root: "LeaveApplication")
  end

  def build_leave_assign_params(user, pto_request, existing_leave)
    params = {"Employee" => {"EmployeeID" => user.xero_id}}
    params["Employee"].merge!({"PayTemplate"=>{"LeaveLines"=> [] }}) 
    line = {"LeaveTypeID"=>pto_request.pto_policy.xero_leave_type_id, "CalculationType"=>"FIXEDAMOUNTEACHPERIOD", "AnnualNumberOfUnits"=>"#{annual_units(pto_request.pto_policy)}"}
    params["Employee"]["PayTemplate"]["LeaveLines"].push(line)
    
    existing_leave.each do |leave_line|
      params["Employee"]["PayTemplate"]["LeaveLines"].push(leave_line)
    end
    
    params.to_xml(root: "Employees")
  end

  def helper_service
    HrisIntegrationsService::Xero::Helper.new
  end
end