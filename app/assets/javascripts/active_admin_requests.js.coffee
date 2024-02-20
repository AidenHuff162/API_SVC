@load_company_team_and_locations = (comp_id)->
  $.ajax '/api/v1/admin/active_admin/admin_requests/load_company_team_and_locations',
    type: "get",
    data: { comp_id: comp_id, access_token: get_access_token() },
    dataType: 'json',
    contentType: 'application/json'
    success: (data)->
     for location in data.locations
      generate_option_element(location.name,location.id,'q_location_id')
     for team in data.company_teams
      generate_option_element(team.name,team.id,'q_team_id')

$(window).load ->	
	$('body.admin_users select#q_company_id').on "change",->
    comp_id = $('#q_company_id').val()
    $("#q_team_id option").remove()    
    $("#q_location_id option").remove()
    generate_option_element('Any','','q_team_id')
    generate_option_element('Any','','q_location_id')
    if comp_id
      load_company_team_and_locations(comp_id)	 

@get_document_url = (paperwork_request_entry_id,params)->	
 $('#dialog').html ''          
 get_document(paperwork_request_entry_id,params)    

@view_docs = (paperwork_request)->
  $("#dialog").dialog
    modal: true,    
    resizable: false 
    width: 680,
    height: 500,
    draggable: false   
    close : -> 
      $('body').removeClass('show_dialog')
    buttons: Close: ->
     $(this).dialog 'close'        
     return
    open: ->  
     $('#dialog').parent().css({top:"20px",position:"fixed"}).end().dialog('open')
     $('.ui-dialog-title').addClass('resize_dialog_title')
     $('body').addClass('show_dialog')
     $('.ui-helper-clearfix:last-child').hide()
     $("<h3 id='loading_div' />").html('Loading...').appendTo('#dialog')
     $('.ui-dialog-buttons').addClass('set_height_dialog')
     $('#loading_div').addClass('set_heading_size')
  if !paperwork_request['unsigned_document'] && !paperwork_request['signed_document']
    $('#loading_div').html('An Error Occurred!')
    return
  $('.ui-dialog-buttons').removeClass('set_height_dialog')    
  $('#dialog').html ''      
  if paperwork_request['unsigned_document']      
    $("<iframe id='doc_frame' />").attr('src',paperwork_request['unsigned_document']['url']).appendTo('#dialog')
  else
    $("<iframe id='doc_frame' />").attr('src',paperwork_request['signed_document']['url']).appendTo('#dialog')
  $('#doc_frame').addClass('dialog_size')
  return

@download_docs = (paperwork_request)->
  if(paperwork_request['unsigned_document'])   
    url = paperwork_request['unsigned_document']['url']    
  if(paperwork_request['signed_document'])   
    url = paperwork_request['signed_document']['url']       
  if !url
    alert('Document does not Exist')
    return
  a = document.createElement('a')
  a.href = url
  a.download = url.substr(url.lastIndexOf('/') + 1);
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);                    

@generate_option_element = (html,value,select_element_id)->
  select = document.getElementById(select_element_id)
  opt = document.createElement('option')
  opt.value = value
  opt.innerHTML = html
  select.appendChild(opt)

@get_document = (paperwork_request_entry_id,params) ->
  $.ajax '/api/v1/admin/active_admin/admin_requests/document_url',
    type: "get",
    data: {paperwork_request_entry_id:paperwork_request_entry_id, access_token: get_access_token()},
    dataType: 'json',
    contentType: 'application/json'
    success: (paperwork_request)->    
     if params == 0
      view_docs(paperwork_request)
     else
      download_docs(paperwork_request)
    error: (data)->
      $('#loading_div').html('An Error Occurred!') 

get_access_token = ->
  match = document.cookie.match(new RegExp('(^| )' + 'admin_access_token' + '=([^;]+)'))
  match[2]

$(document).ready ->
  $('.delete_doc').click ->
    match = document.cookie.match(new RegExp('(^| )' + 'admin_access_token' + '=([^;]+)'))
    new_url = $(this).attr("href") + "&access_token=" + match[2]
    $(this).attr('href', new_url)
