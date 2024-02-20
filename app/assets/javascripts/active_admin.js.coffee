#= require active_admin_custom.min
#= active_admin/base
#= active_material
#= require parsley
#= require quill/config
#= require active_admin/json_editor
#= require integration_management

jQuery ->
  toolbarOptions = [
      [
        'bold'
        'italic'
        'underline'
      ]
      [
        { 'list': 'ordered' }
        { 'list': 'bullet' }
      ]
      [{'header': [1, 2, 3, false]}]
      [
        'link'
        'image'
        'code-block'
        'clean'
      ]
    ]

  integration_management()

  humanize = (str) ->
    if str
      str.trim().split(/\s+/).map((str) ->
        str.replace(/_/g, ' ').replace(/\s+/, ' ').trim()
      ).join(' ').toLowerCase().replace /^./, (m) ->
        m.toUpperCase()

  populateCustomFields = (company_id, profile_setup, profile_setup_type) ->
    if profile_setup == 'profile_fields'
      params = { company_id: company_id, section: profile_setup_type, is_profile_field: true }
    else
      params = { company_id: company_id, custom_table_id: profile_setup_type, is_custom_table: true }

    $.ajax
      url: '/admin/greenhouse_cfs/custom_field_index'
      dataType: 'json'
      data: params
      success: (data) ->
        if data.errors
          alert data.errors
        else
          custom_fied_name = $('#custom_field_name')
          custom_fied_type = $('#custom_field_field_type')
          custom_fied_name.html('')
          custom_fied_type.html('')

          $.each data, ->
            custom_fied_name.append $('<option />').val(this.id).text(this.name)
            custom_fied_type.append $('<option />').val(this.id).text(humanize(this.field_type))
        return

  populateCustomTable = (company) ->
    selected_company_id = $(company).children("option:selected").val()
    $.ajax
      url: '/admin/greenhouse_cfs/custom_table_index'
      dataType: 'json'
      data: company_id: selected_company_id
      success: (data) ->
        if data.errors
          alert data.errors
        else
          custom_table = $('#custom_field_custom_table_id')
          custom_table.html('')

          $.each data, ->
            custom_table.append $('<option />').val(this[1]).text(this[0])
        return

  manageProfileSetup = (company, profile_setup) ->
    selected_profile_setup = $(profile_setup).children("option:selected").val()
    selected_company_id = $(company).children("option:selected").val()

    if selected_profile_setup == 'custom_table'
      $('#custom_field_section').parent().hide()
      $('#custom_field_custom_table_id').parent().show()
    else
      $('#custom_field_section').parent().show()
      $('#custom_field_custom_table_id').parent().hide()

  fetchCustomFields = (company, profile_setup) ->
    selected_company_id = $(company).children("option:selected").val()
    selected_profile_setup = $(profile_setup).children("option:selected").val()

    if selected_profile_setup == 'profile_fields'
      section = $('#custom_field_section')
      selected_profile_setup_type = $(section).children("option:selected").val()
      populateCustomTable(company)
    else
      custom_table = $('#custom_field_custom_table_id')
      selected_profile_setup_type = $(custom_table).children("option:selected").val()

    populateCustomFields(selected_company_id, selected_profile_setup, selected_profile_setup_type)

  greenhouse_cf = ->
    company = $('#custom_field_company_id')
    profile_setup = $('#custom_field_profile_setup')
    field_name = $('#custom_field_name')

    section = $('#custom_field_section')
    custom_table = $('#custom_field_custom_table_id')

    field_id = $(field_name).children("option:selected").val()

    if !field_id
      company.ready ->
        selected_profile_setup = $(profile_setup).children("option:selected").val()
        fetchCustomFields(company, profile_setup) if selected_profile_setup != 'custom_table'

      profile_setup.ready ->
        manageProfileSetup(company, profile_setup)

      custom_table.ready ->
        selected_profile_setup = $(profile_setup).children("option:selected").val()
        fetchCustomFields(company, profile_setup) if selected_profile_setup != 'custom_table'

    company.change ->
      fetchCustomFields(company, profile_setup)

    profile_setup.change ->
      manageProfileSetup(company, profile_setup)
      populateCustomTable(company)
      fetchCustomFields(company, profile_setup)

    section.change ->
      fetchCustomFields(company, profile_setup)

    custom_table.change ->
      fetchCustomFields(company, profile_setup)

    field_name.change ->
      field_id = $(field_name).children("option:selected").val()
      $('#custom_field_field_type').find('option[value="' + field_id + '"]').attr("selected", "selected")
  greenhouse_cf()

  greenhouse_df = ->
    $('#company_prefrences').hide()
  greenhouse_df()

  $("#greenhouse_custom_field").submit (e) ->
    e.preventDefault()

    field_type = $('#custom_field_field_type').children("option:selected").text()
    ats_field_type = $('#custom_field_ats_mapping_field_type').children("option:selected").text()

    if field_type == ats_field_type
      this.submit()
    else
      alert('ATS Mapping Field Type should be same as Sapling Field Type')

  onboard_email_required = ->
    onboard_email = $('#user_onboard_email :selected').text()

    if onboard_email == 'Both'
      $('#user_email').attr 'required', true
      $('#user_personal_email').attr 'required', true

    else if onboard_email == 'Personal'
      $('#user_email').removeAttr 'required'
      $('#user_personal_email').attr 'required', true

    else
      $('#user_personal_email').removeAttr 'required'
      $('#user_email').attr 'required', true

  $("form#company.user").submit (e) ->
    e.preventDefault()

    if $('#user_onboard_email :selected').text() == 'Personal'
      $('#user_provider').val 'personal_email'
    else
      $('#user_provider').val 'email'

    this.submit()
    false

  window.ParsleyValidator.addValidator('validateDate', ((value, requirement) ->
    /(19|20)[0-9]{2}-([0-9][1-9]|[1-9][0-9])-([0-9][1-9]|[1-9][0-9])/.test(value)
  ), 32)

  onboard_email_required()

  $('#user_onboard_email').change ->
    onboard_email_required()

  replace_options = (options) ->
    options.replace(/([ #;&,.+*~\':"!^$[\]()=>|\/@])/g, '\\$1')

  teams = $('#user_team_id').html()
  locations = $('#user_location_id').html()
  $('#user_company_id').change ->
    company = $('#user_company_id :selected').text()

    team_options = $(teams).filter("optgroup[label='#{replace_options(company)}']").html()
    if team_options
      $('#user_team_id').html(team_options)
      $('#user_team_id').parent().show()
    else
      $('#user_team_id').empty()
      $('#user_team_id').parent().hide()

    location_options = $(locations).filter("optgroup[label='#{replace_options(company)}']").html()
    if location_options
      $('#user_location_id').html(location_options)
      $('#user_location_id').parent().show()
    else
      $('#user_location_id').empty()
      $('#user_location_id').parent().hide()

  @validate_change_password_form = ->
    password = $('#admin_user_password').val()
    confirm_password = $('#admin_user_password_confirmation').val()
    return true if password == confirm_password
    alert 'Password and Confirm Password should be same'
    return false
  
  $('#user_password').keyup ->
    password         = $('#user_password').val()
    lenght_eight      = password
    lower_characters  = password.match(/[a-z]/g)
    numbers           = password.match(/[\d]/g)
    upper_characters  = password.match(/[A-Z]/g)
    special_symbols   = password.match(/[^\w]/g)

    submit_button = document.getElementById("user_submit_action")
    if password.length == 0 
      submit_button.firstElementChild.disabled = false

    eight_head = document.getElementsByClassName("show_password_head_one")
    eight_text = document.getElementsByClassName("show_password_text_one") 
    if  lenght_eight.length > 7
      eight_head[0].style.background = "#82e2d5"
      eight_text[0].style.color = "black"
    else
      eight_head[0].style.background = "#00000061"
      eight_text[0].style.color = "#00000061"   

    number_head = document.getElementsByClassName("show_password_head_two")
    number_text = document.getElementsByClassName("show_password_text_two") 
    if  numbers != null
      number_head[0].style.background = "#82e2d5"
      number_text[0].style.color = "black"
    else
      number_head[0].style.background = "#00000061"
      number_text[0].style.color = "#00000061"  

    lower_head = document.getElementsByClassName("show_password_head_three")
    lower_text = document.getElementsByClassName("show_password_text_three") 
    if lower_characters != null
      lower_head[0].style.background = "#82e2d5"
      lower_text[0].style.color = "black"
    else
      lower_head[0].style.background = "#00000061"
      lower_text[0].style.color = "#00000061"

    symbol_head = document.getElementsByClassName("show_password_head_four")
    symbol_text = document.getElementsByClassName("show_password_text_four") 
    if  special_symbols != null
      symbol_head[0].style.background = "#82e2d5"
      symbol_text[0].style.color = "black"
    else
      symbol_head[0].style.background = "#00000061"
      symbol_text[0].style.color = "#00000061"   

    uper_head = document.getElementsByClassName("show_password_head_five")
    uper_text = document.getElementsByClassName("show_password_text_five")   
    if upper_characters != null
      uper_head[0].style.background = "#82e2d5"
      uper_text[0].style.color = "black"
    else
      uper_head[0].style.background = "#00000061"
      uper_text[0].style.color = "#00000061"

    if upper_characters != null && special_symbols != null && lower_characters != null && numbers != null && lenght_eight.length > 7
      verifyPasswordStrength(password, submit_button)
    else if password.length !=0
      submit_button.firstElementChild.disabled = true
      document.getElementsByClassName("show_password_head_six")[0].style.background = "#00000061"
      document.getElementsByClassName("show_password_text_six")[0].style.color = "#00000061"
    return

  verifyPasswordStrength = (password, submit_button) ->
    $.ajax
      url: '/admin/users/verify_password_strength'
      dataType: 'json'
      data: password: password
      success: (data) ->
        not_guessable_head = document.getElementsByClassName("show_password_head_six")
        not_guessable_text = document.getElementsByClassName("show_password_text_six")
        if data.password_acceptable == true
          not_guessable_head[0].style.background = "#82e2d5"
          not_guessable_text[0].style.color = "black"
          submit_button.firstElementChild.disabled = false
        else if data.password_acceptable != true
          not_guessable_head[0].style.background = "#00000061"
          not_guessable_text[0].style.color = "#00000061"
          submit_button.firstElementChild.disabled = true
        return

  $('#integration_field_mapping_company_id').change ->
    selected_company_id = $('#integration_field_mapping_company_id').val()
    removeCustomFields()
    $.ajax
      url: '/admin/integration_field_mappings/integration_instances'
      dataType: 'json'
      data: company_id: selected_company_id
      success: (data) ->
        if data.errors
          alert data.errors
        else
          $('#integration_field_mapping_integration_instance_id').html('<option value = "" text = "" />')
          $.each data, ->
            $('#integration_field_mapping_integration_instance_id').append($('<option>', {
              value: this.id,
              text : this.name 
            }));
          return

  removeCustomFields = -> 
    $('#integration_field_mapping_custom_field_id').html('<option value = "" text = "" />')

  $('#integration_field_mapping_company_id').change ->
    selected_company_id = $('#integration_field_mapping_company_id').val()
    $.ajax
      url: '/admin/integration_field_mappings/custom_fields'
      dataType: 'json'
      data: company_id: selected_company_id
      success: (data) ->
        if data.errors
          alert data.errors
        else
          $('#integration_field_mapping_custom_field_id').html('<option value = "" text = "" />')
          $.each data, ->
            $('#integration_field_mapping_custom_field_id').append($('<option>', { 
              value: this.id,
              text : this.name 
            }));
          return

  $('#integration_field_mapping_custom_field_id').change ->
    selected_custom_field_name = $('#integration_field_mapping_custom_field_id :selected').text()
    $('#integration_field_mapping_integration_field_key').val(jQuery.camelCase(selected_custom_field_name.replace(/[^A-Z0-9]/ig, "")))
    
    selected_company_id = $('#integration_field_mapping_company_id').val()
    url = window.location.href if window.location.href.split('integration_field_mappings/')[1] == 'new'
    split_url = url.split('integration_field_mappings/') 
    if split_url[1].search('edit') > -1
      integration_field_mapping_id = split_url[1].split('/')[0]
    else
      integration_field_mapping_id = null

    selected_custom_field_id = $('#integration_field_mapping_custom_field_id :selected').val()
    $.ajax
      url: '/admin/integration_field_mappings/field_position'
      dataType: 'json'
      data: custom_field_id: selected_custom_field_id, company_id: selected_company_id, integration_field_mapping_id: integration_field_mapping_id
      success: (data) ->
        if data.errors
          alert data.errors
        else
          $('#integration_field_mapping_field_position').val(data)
          return

  $("#integration_error_slack_webhook_configure_app").change ->
    if $("#integration_error_slack_webhook_configure_app").val() != 'teams'
      $("#integration_error_slack_webhook_channel").attr('required', 'required')
      $("#integration_error_slack_webhook_channel_input").show()
    else
      $("#integration_error_slack_webhook_channel").removeAttr('required')
      $("#integration_error_slack_webhook_channel_input").hide()

  if $("#integration_error_slack_webhook_channel").length > 0 && $("#integration_error_slack_webhook_configure_app").length > 0 && $("#integration_error_slack_webhook_configure_app").val() == 'teams'
    $("#integration_error_slack_webhook_channel").removeAttr('required')
    $("#integration_error_slack_webhook_channel_input").hide()
