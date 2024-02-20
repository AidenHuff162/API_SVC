@integration_management = ->
  # integration_inventory_management()

  inventory = $('#integration_configuration_integration_inventory_id')

  category = $('#integration_configuration_category')
  field_type = $('#integration_configuration_field_type')
  field_name = $('#integration_configuration_field_name')
  toggle_context = $('#integration_configuration_toggle_context')
  toggle_identifier = $('#integration_configuration_toggle_identifier')
  width = $('#integration_configuration_width')

  setFieldValue($(field_type).children("option:selected").val())
  setCategoryFields($(category).children("option:selected").val(), field_type, toggle_context, toggle_identifier, field_name, width)
  
  inventory.change ->
    populateToggleKeys(inventory)

  field_type.change ->
    set_category_change(category, field_type, toggle_context, toggle_identifier, field_name, width)

  category.change ->
    set_category_change(category, field_type, toggle_context, toggle_identifier, field_name, width)

  $('#enable_api_name').click ->
    $('#integration_inventory_api_identifier').attr("disabled", false)

@set_category_change = (category, field_type, toggle_context, toggle_identifier, field_name, width) ->
  selected_category_value = $(category).children("option:selected").val()
  selected_type_value = $(field_type).children("option:selected").val()

 
  setCategoryFields(selected_category_value, field_type, toggle_context, toggle_identifier, field_name, width)
  setFieldValue(selected_type_value)

@setFieldValue = (selected_type_value) ->
  if selected_type_value == 'dropdown' 
    $('#integration_configuration_dropdown_options').parent().show()
    hideField($('#integration_configuration_vendor_domain'))
  else if selected_type_value == 'subdomain'
    $('#integration_configuration_vendor_domain').parent().show()
    hideField($('#integration_configuration_dropdown_options'))
  else
    $('#integration_configuration_vendor_domain').parent().hide()
    hideField($('#integration_configuration_dropdown_options'))

@setCategoryFields = (selected_category_value, field_type, toggle_context, toggle_identifier, field_name, width) ->
  if selected_category_value == 'settings'
    toggle_context.parent().show()
    toggle_identifier.parent().show()
    hideField(width)
    hideField(field_type)
    hideField(field_name)
  else if selected_category_value == 'credentials'
    hideField(toggle_identifier)
    hideField(toggle_context)
    field_type.parent().show()
    field_name.parent().show()
    width.parent().show()

@populateToggleKeys = (inventory)->
  selected_inventory_id = $(inventory).children("option:selected").val()
  $.ajax
    url: '/admin/integration_configurations/get_toggle_identifiers'
    dataType: 'json'
    data: inventory_id: selected_inventory_id
    success: (data) ->
      if data.errors
        alert data.errors
      else
        toggle_identifiers = ['Can Import Data', 'Can Export Updation', 'Enable Onboarding Templates', 'Enable International Templates', 'Enable Company Code', 'Enable Tax Type', 'Can Delete Profile', 'Can Invite Profile', 'Can Export New Profile']
        toggle_identifier = $('#integration_configuration_toggle_identifier')
        toggle_identifier.html('')
        $.each toggle_identifiers, (index, identifier)->
          if !data.includes(identifier)
            toggle_identifier.append $('<option />').val(identifier).text(identifier)
      return

@integration_inventory_management = -> 
  category = $('#integration_inventory_category')
  api_identifier = $('#integration_inventory_api_identifier')

  category.change ->
    get_api_identifiers(category, api_identifier)

@get_api_identifiers = (category, api_identifier) ->
  selected_category_value = $(category).children("option:selected").val()
  api_identifiers = []
  $.ajax
    url: '/admin/integration_inventories/get_integations'
    dataType: 'json'
    data: category: selected_category_value
    success: (data) ->
      api_identifier.html('')
      if data.errors
        alert data.errors
      else if selected_category_value == 'Learning & Development'
        api_identifiers = [['lessonly', 'Lessonly'], ['learn_upon', 'Learn Upon']]
        set_api_identifiers(api_identifier, api_identifiers, data)
      return

@set_api_identifiers = (api_identifier, api_identifiers, data) ->
  $.each api_identifiers, ->
    if !data.includes(this[0])
      api_identifier.append $('<option />').val(this[0]).text(this[1])

hideField = (field) ->
  field.parent().hide()
  field.val("")

