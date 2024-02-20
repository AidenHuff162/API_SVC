class HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder

  def build_applicant_onboard_params(data)
    return {} unless data.present?

    params = {
      events: [{
        data: {
          transform: {
            eventReasonCode: {
              codeValue: 'NEW'
            },
            applicant: {
              person: {
                legalName: {
                  givenName: data[:first_name],
                  familyName1: data[:last_name],
                  nickName: data[:preferred_name],
                  middleName: data[:middle_name]
                },
                governmentIDs: [{
                  idValue: data[:identification_number],
                  nameCode: {
                    codeValue: data[:identification_code]
                  },
                  countryCode: data[:country_code]
                }],
                maritalStatusCode: {
                  codeValue: data[:federal_marital_status]
                },
                birthDate: data[:date_of_birth],
                genderCode: {
                  codeValue: data[:gender]
                },
                legalAddress: {
                  nameCode: {
                    codeValue: 'Personal Address 1'
                  },
                  lineOne: data[:home_address][:line1],
                  lineTwo: data[:home_address][:line2],
                  cityName: data[:home_address][:city_name],
                  countrySubdivisionLevel1: {
                    codeValue: data[:home_address][:country_subdivission_level]
                  },
                  countryCode: data[:home_address][:country_code],
                  postalCode: data[:home_address][:postal_code]
                },
                communication: {
                  emails: [{ emailUri: data[:personal_email] }],
                  landlines: [{
                    countryDialing: data[:home_phone_number][:country_dialing],
                    areaDialing: data[:home_phone_number][:area_dialing],
                    dialNumber: data[:home_phone_number][:dial_number],
                    access: data[:home_phone_number][:access]
                  }],
                  mobiles: [{
                    countryDialing: data[:mobile_phone_number][:country_dialing],
                    areaDialing: data[:mobile_phone_number][:area_dialing],
                    dialNumber: data[:mobile_phone_number][:dial_number],
                    access: data[:mobile_phone_number][:access]
                  }]
                }
              }
            },
            jobOffer: {
              offerTerms: {
                expectedStartDate: data[:start_date],
                compensation: {
                  payCycleCode: {
                    codeValue: data[:pay_frequency]
                  }
                }
              },
              offerAssignment: {
                workerTypeCode: {
                  codeValue: data[:employment_status]
                },
                homeOrganizationalUnits: [
                  { nameCode: { codeValue: data[:department] }, typeCode: { codeValue: 'Department' } },
                  { nameCode: { codeValue: data[:location] }, typeCode: { codeValue: 'Location' } },
                  { nameCode: { codeValue: data[:business_unit] }, typeCode: { codeValue: 'Business Unit' } }
                ]
              }
            }
          }
        }
      }]
    }

    params[:events].first[:data][:transform][:jobOffer][:offerAssignment][:jobCode] = {codeValue: data[:job_title]} if data[:job_title].present?
    params[:events].first[:data][:transform][:applicant][:person][:raceCode] = {identificationMethodCode: {codeValue: data[:race_id_method]}, codeValue: data[:ethnicity]} if data[:ethnicity].present?

    case data[:rate_type]
    when 'H'
      params[:events].first[:data][:transform][:jobOffer][:offerTerms][:compensation][:baseRemuneration] = {hourlyRateAmount:{nameCode:{codeValue: data[:rate_type]}, amountValue: data[:pay_rate][:currency_value], currencyCode: data[:pay_rate][:currency_type]}}
    when 'D'
      params[:events].first[:data][:transform][:jobOffer][:offerTerms][:compensation][:baseRemuneration] = {dailyRateAmount:{nameCode:{codeValue: data[:rate_type]}, amountValue: data[:pay_rate][:currency_value], currencyCode: data[:pay_rate][:currency_type]}}
    when 'S'
      params[:events].first[:data][:transform][:jobOffer][:offerTerms][:compensation][:baseRemuneration] = {payPeriodRateAmount:{nameCode:{codeValue: data[:rate_type]}, amountValue: data[:pay_rate][:currency_value], currencyCode: data[:pay_rate][:currency_type]}}
    end

    if data[:onboarding_template]
      params[:events].first[:data][:transform][:templateNameCode] = {codeValue: data[:onboarding_template]}
    end

    if data[:company_code]
      params[:events].first[:data][:transform][:jobOffer][:offerAssignment][:payrollGroupCode] = data[:company_code]
    end

    params
  end

  def build_v2_applicant_onboard_params(data, environment)
    params = {
      applicantOnboarding: {
        onboardingTemplateCode: {
          code: data[:onboarding_template]
        },
        onboardingStatus: {
          statusCode: {
            code: 'inprogress',
            name: 'inprogress'
          }
        },
        applicantPersonalProfile: {
          birthName:{
            givenName: data[:first_name],
            middleName: data[:middle_name],
            familyName: data[:last_name]
          },
          preferredName: {
            nickName: data[:preferred_name]
          },
          maritalStatusCode:{
            code: data[:federal_marital_status]
          },
          birthDate: data[:date_of_birth],
          genderCode:{
            code: data[:gender]
          },          
          communication:{
            landlines:[{
              countryDialing: data[:home_phone_number][:country_dialing],
              areaDialing: data[:home_phone_number][:area_dialing],
              dialNumber: data[:home_phone_number][:dial_number],
              access: data[:home_phone_number][:access]

            }],
            mobiles:[{
              countryDialing: data[:mobile_phone_number][:country_dialing],
              areaDialing: data[:mobile_phone_number][:area_dialing],
              dialNumber: data[:mobile_phone_number][:dial_number],
              access: data[:mobile_phone_number][:access]
            }],
            emails:[{emailUri: data[:personal_email]}]

          },
          governmentIDs:[{
            id: data[:identification_number],
            nameCode:{
              code: data[:identification_code]
            }
          }]

        },
        applicantWorkerProfile:{
          "hireReasonCode": {
            "code": "CURR"
            },
          hireDate: data[:start_date],
          homeOrganizationalUnits:[
            {
              unitTypeCode: {
                code: "BusinessUnit"
              },
              nameCode: {
                code: data[:business_unit]
              }
            },
            {
              unitTypeCode: {
                code: "HomeDepartment"
              },
              nameCode: {
                code: data[:department]
              }
            }
          ],
          reportsTo: {
            positionID: data[:manager_adp_position_id]
          },
          homeWorkLocation:{
            nameCode:{
              code: data[:location]
            }
          },
          workerTypeCode: {
            code: data[:employment_status]
          },
          businessCommunication:{
            emails:[{emailUri: data[:company_email]}]
          }
        },
        applicantPayrollProfile:{
          payCycleCode:{
            code: data[:pay_frequency]
          }
        }
      }
    }
    params[:applicantOnboarding][:applicantPersonalProfile][:legalAddress] = { lineOne: data[:home_address][:line1], lineTwo: data[:home_address][:line2], postalCode: data[:home_address][:zip], cityName: data[:home_address][:city_name], countryCode: data[:home_address][:country_code], subdivisionCode:{ code: data[:home_address][:country_subdivission_level] }} if data[:home_address].present? && (data[:home_address][:line1].present? || data[:home_address][:line2].present?)
    params[:applicantOnboarding][:applicantWorkerProfile][:job] = { jobCode: {code: data[:job_title]}} if data[:job_title].present?
    params[:applicantOnboarding][:applicantPersonalProfile][:raceCode] = {identificationMethodCode: {code: data[:race_id_method]}, code: data[:race] } if data[:race].present?
    params[:applicantOnboarding][:applicantPersonalProfile][:ethnicityCode] = {code: data[:ethnicity] } if data[:ethnicity].present?  
    params[:applicantOnboarding][:applicantPayrollProfile].merge!({payrollGroupCode:  data[:company_code]}) if data[:company_code].present?
    params[:applicantOnboarding][:countryCode] = data[:worked_in_country].upcase if data[:worked_in_country].present?
    params[:applicantOnboarding][:applicantPersonalProfile][:communication][:emails][0][:notificationIndicator] = true if !data[:company_email] && environment == 'CAN'
    params[:applicantOnboarding][:applicantPersonalProfile][:governmentIDs].first[:expirationDate] = data[:sin_expiry_date] if data[:sin_expiry_date]

    case data[:rate_type]
    when 'H'
      params[:applicantOnboarding][:applicantPayrollProfile][:baseRemuneration]= {hourlyRateAmount: {amount: data[:pay_rate][:currency_value], currencyCode: data[:pay_rate][:currency_type]} }
    when 'D'
      params[:applicantOnboarding][:applicantPayrollProfile][:baseRemuneration]= {dailyRateAmount: {amount: data[:pay_rate][:currency_value], currencyCode: data[:pay_rate][:currency_type]} }
    when 'S'
      params[:applicantOnboarding][:applicantPayrollProfile][:baseRemuneration]= {payPeriodRateAmount: {amount: data[:pay_rate][:currency_value], currencyCode: data[:pay_rate][:currency_type]} }
    end
    
    params
  end

  def build_change_personal_communication_email_params(data)
    params = {
      "events": [{
        "eventNameCode": {"codeValue": "worker.personal-communication.email.change"},
        "data": {
          "eventContext": {"worker": {"associateOID": data[:associate_id]}},
          "transform": {"worker": {"person": {"communication": {"email": {"emailUri": data[:personal_email]}}}}}
        }
      }]
    }
  end

  def build_change_business_communication_email_params(data)
    params = {
      "events": [{
        "eventNameCode": {"codeValue": "worker.businessCommunication.email.change"},
        "data": {
          "eventContext": {"worker": {"associateOID": data[:associate_id]}},
          "transform": {"worker": {"businessCommunication": {"email": {"emailUri": data[:company_email]}}}}
        }
      }]
    }
  end

  def build_change_middle_name_params(data)
    params = {
      "events": [{
        "eventNameCode": {"codeValue": "worker.legal-name.change"},
        "data": {
          "eventContext": {"worker": {"associateOID": data[:associate_id]}},
          "transform": {"worker": {"person": {"legalName": {"givenName": data[:first_name], "familyName1": data[:last_name], "middleName": data[:middle_name]}}}}
        }
      }]
    }
  end

  def build_change_preferred_name_params(data)
    params = {
      "events": [{
       "data": {
         "eventContext": {"worker": {"associateOID": data[:associate_id]}},
         "transform": {"worker": {"person": {"preferredName": {"givenName": data[:preferred_name]}}}}
        }
      }]
    }
  end

  def build_change_marital_status_params(data)
    params = {
      "events": [{
        "eventNameCode": {"codeValue": "worker.marital-status.change"},
        "data": {
          "eventContext": {"worker": {"associateOID": data[:associate_id]}},
          "transform": {"worker": {"person": {"maritalStatusCode": {"codeValue": data[:federal_marital_status]}}}}
        }
      }]
    }
  end

  def build_change_legal_address_params(data)
    params = {
      "events": [{
        "eventNameCode": {"codeValue": "worker.legal-address.change"},
        "data": {
          "eventContext": {"worker": {"associateOID": data[:associate_id]}},
          "transform": {"worker": {"person": {"legalAddress": {"nameCode": {"codeValue": "Personal Address 1"}, "lineOne": data[:home_address][:line1], 
          "lineTwo": data[:home_address][:line2], "cityName": data[:home_address][:city_name], "countrySubdivisionLevel1": {"codeValue": data[:home_address][:country_subdivission_level]}, 
          "countryCode": data[:home_address][:country_code], "postalCode": data[:home_address][:postal_code]}}}}
        }
      }]
    }
  end

  def build_change_personal_communication_landline_params(data)
    params = {
      "events": [{
        "eventNameCode": {"codeValue": "worker.personal-communication.landline.change"},
        "data": {
          "eventContext": {"worker": {"associateOID": data[:associate_id]}},
          "transform": {"worker": {"person": {"communication": {"landline": {"countryDialing": data[:home_phone_number][:country_dialing], "areaDialing": data[:home_phone_number][:area_dialing], 
            "dialNumber": data[:home_phone_number][:dial_number], "access": data[:home_phone_number][:access]}}}}}
        }
      }]
    }
  end

  def build_change_personal_communication_mobile_params(data)
    params = {
      "events": [{
        "eventNameCode": {"codeValue": "worker.personal-communication.mobile.change"},
        "data": {
          "eventContext": {"worker": {"associateOID": data[:associate_id]}},
          "transform": {"worker": {"person": {"communication": {"mobile": {"countryDialing": data[:mobile_phone_number][:country_dialing], "areaDialing": data[:mobile_phone_number][:area_dialing], 
            "dialNumber": data[:mobile_phone_number][:dial_number], "access": data[:mobile_phone_number][:access]}}}}}
        }
      }]
    }
  end

  def build_change_ethnicity_params(data)
    params = {
      "events": [{
        "eventNameCode": {"codeValue": "worker.race.change"},
        "data": {
          "eventContext": {"worker": {"associateOID": data[:associate_id]}},
          "transform": {"worker": {"person": {"raceCode": {"identificationMethodCode": {"codeValue": data[:race_id_method]}, "codeValue": data[:ethnicity]}}}}
        }
      }]
    }
  end

  def build_change_manager_params(data)
    params = {
      "events": [{
        "eventNameCode": {"codeValue": "worker.reports-to.modify"},
        "data": {
          "eventContext": {"associateOID": data[:associate_id], "workAssignmentID": data[:work_assignment_id]},
          "transform": {"workAssignment": {"reportsTo": [{"positionID": data[:manager_adp_position_id] }] }, "effectiveDateTime": data[:effective_date]}
        }
      }]
    }
  end

  def build_change_base_remunration_params(data)
    return unless data[:rate_type] && data[:pay_rate] && data[:pay_rate][:currency_value] && data[:pay_rate][:currency_type]
    rate_amount_key = ''

    case data[:rate_type]
    when 'H'
      rate_amount_key = 'hourlyRateAmount'   
    when 'D'
      rate_amount_key = 'dailyRateAmount'
    when 'S'
      rate_amount_key = 'payPeriodRateAmount'
    end

    params = {
      "events": [{
        "eventNameCode": {"codeValue": "worker.work-assignment.base-remuneration.change"},
        "data": {
          "eventContext": {"worker": {"associateOID": data[:associate_id], "workAssignment": {"itemID": data[:work_assignment_id]}}},
          "transform": {"eventReasonCode": {"codeValue": data[:event_reason_code]}, "effectiveDateTime": data[:effective_date],
            "workAssignment": {"baseRemuneration": {"#{rate_amount_key}": {"nameCode": {"codeValue": data[:rate_type]}, "amountValue": data[:pay_rate][:currency_value], "currencyCode": data[:pay_rate][:currency_type]}}}}
        }
      }]
    }
  end

  def build_change_string_custom_field_params(data)
    {
      'events': [{
        'eventNameCode': {
          'codeValue': 'worker.customField.string.change'
        },
        'data': {
          'eventContext': {
            'worker': {
              'associateOID': data[:associate_id], 
              'customFieldGroup': {
                'stringField': { 
                  'itemID': data[:adp_item_id] 
                }
              }
            }
          },
          'transform': {
            'worker': {
              'customFieldGroup': { 
                'stringField': { 
                  'nameCode': { 
                    'shortName': data[:adp_short_name] 
                  }, 
                  'stringValue': data[:adp_string_value]
                }
              }
            }
          }
        }
      }]
    }
  end

  def build_terminate_employee_params(position_id, data)
    params = {
      'events': [{
        'eventNameCode': {'codeValue': 'worker.work-assignment.terminate'},
        'data': {
          'eventContext': {'worker': {'workAssignment': {'itemID': position_id}}},
          'transform': {'worker': {'workAssignment': {'terminationDate': data[:termination_date],'lastWorkedDate': data[:last_worked_date], 'rehireEligibleIndicator': data[:rehire_eligible_indicator], 'severanceEligibleIndicator': data[:severance_eligible_indicator], 'assignmentStatus': {'reasonCode': {'codeValue': data[:reason_code]}}}}}
        }
      }]
    }
  end

  def build_rehire_employee_params(data)
    params = {
      'events': [{
        'eventNameCode': {'codeValue': 'worker.rehire'},
        'data': {
          'transform': {'effectiveDateTime': data[:effective_date], 'worker': {'associateOID': data[:associate_id], 'workerDates':{'rehireDate': data[:rehire_date]}, 'workerStatus':{'reasonCode': {'codeValue': data[:reason_code]}}, 'workAssignment': {'positionID': data[:position_id]}}}
        }
      }]
    }
  end
end