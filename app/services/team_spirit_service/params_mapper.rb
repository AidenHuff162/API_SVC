class TeamSpiritService::ParamsMapper

  def build_starters_changers_parameter_mappings
    {
      BANK1: {name: 'Bank Account Name', is_custom: true },
      BACC: {name: 'Bank Account Number', is_custom: true },
      ADD1: {name: 'Line1', is_custom: true },
      ADD2: {name: 'Line2', is_custom: true },
      ADD3: {name: 'City', is_custom: true },
      ADD4: {name: 'State', is_custom: true },
      PKBHTYPE: {name: 'Bank Holiday Profile', is_custom: true },
      BANK2: {name: 'Bank Name', is_custom: true },
      BHOURS: {name: 'Basic Hours', is_custom: true },
      BANK3: {name: 'Bank Branch', is_custom: true },
      EMLWRK: {name: 'Email', is_custom: false },
      CONTSERV: {name: 'Continuous Service Start Date', is_custom: true },
      ATGCONTY: {name: 'Contract Type', is_custom: true },
      BIRTH: {name: 'Date of Birth', is_custom: true },
      BDAYS: {name: 'Days per Week', is_custom: true },
      DEPT: {name: 'Department', is_custom: true },
      RISE: {name: 'Effective Date', is_custom: true},
      EMPCODE: {name: 'Existing Employee Code', is_custom: true },
      ABHEPR: {name: 'Holiday Entitlement Profile', is_custom: true },
      FIRST: {name: 'First Name', is_custom: false },
      CEFTE: {name: 'FTE', is_custom: true },
      CEFP: {name: 'Full Time/Part Time', is_custom: true },
      HOLENT: {name: 'Holiday Entitlement', is_custom: true },
      PKENLK: {name: 'OSP Entlitement Profile ', is_custom: true },
      ABHEPR_DUP: {name: 'Holiday Entitlement Profile', is_custom: true },
      TEL: {name: 'Home Phone Number', is_custom: true },
      JOBTITLE: {name: 'Job Title', is_custom: true },
      MAIDEN: {name: 'Maiden Name', is_custom: true },
      MSTATUS: {name: 'Marital Status', is_custom: true },
      EMMOB: {name: 'Mobile Phone Number', is_custom: true },
      NINUM: {name: 'NI Number',is_custom: true },
      ATGPAYTY: {name: 'Pay Type', is_custom: true },
      METHOD: {name: 'Payment Method', is_custom: true },
      FREQ: {name: '  Payroll Frequency', is_custom: true },
      EMLADD: {name: 'Personal Email', is_custom: false },
      POSTCDE: {name: 'Zip', is_custom: true },
      CEPROBPD: {name: 'Probationary Period', is_custom: true },
      REPORTID: {name: 'Manager', is_custom: false },
      BPAYANN: {name: 'Pay Rate', is_custom: true },
      SECOND: {name: 'Second Name', is_custom: true },
      SEX: {name: 'Gender', is_custom: true},
      SORTC: {name: 'Bank Sort Code', is_custom: true },
      JOIN: {name: 'Start Date', is_custom: false },
      SURNAME: {name: 'Last Name', is_custom: false },
      CEPT: {name: 'Temp/Perm', is_custom: true },
      TITLE: {name: 'Title', is_custom: true},
      DIVISION: {name: 'Location', is_custom: false },
      PKWPIND: {name: 'Work Day Profile', is_custom: true },
      LEAVE: {name: 'Termination Date', is_custom: false }
    }
  end

  def build_leavers_parameter_mappings
    {
      EMPCODE: {name: 'Existing Employee Code', is_custom: true },
      LEAVE: {name: 'Termination Date', is_custom: false }
    }
  end
end
