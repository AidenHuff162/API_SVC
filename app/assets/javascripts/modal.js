jQuery(document).ready(function() {
  window.submit_filters = function()
  {
    if($('#date_to').val()!="" && $('#date_from').val()!="" && (new Date($('#date_to').val())).getDate() < (new Date($('#date_from').val())).getDate() ){
      alert("Date Range is Invalid!");
      return false;
    }
  }

  window.papertrail_button = function() {
    var value = $('#papertrail_search').val();
    if (value.length > 0) {
      $('#papertrail_button').attr('disabled', false);
    } else {
      $('#papertrail_button').attr('disabled', true);
    }
  }

  window.webhook_button = function(){
    var value = $("#webhook_search").val();
    if(value.length>0 )
    {
      $("#webhook_button").attr("disabled", false);
    }else{
      $("#webhook_button").attr("disabled", true);
    }
  }

  window.api_button = function(){
    var value = $("#api_search").val();
    if(value.length>0 )
    {
      $("#api_button").attr("disabled", false);
    }else{
      $("#api_button").attr("disabled", true);
    }
  }

  window.integ_button = function(){
    var value = $("#integ_search").val();
    if(value.length>0 )
    {
      $("#integ_button").attr("disabled", false);
    }else{
      $("#integ_button").attr("disabled", true);
    }
  }

  window.general_button = function(){
    var value = $("#general_search").val();
    if(value.length>0 )
    {
      $("#search_button").attr("disabled", false);
    }else{
      $("#search_button").attr("disabled", true);
    }
  }
  window.show_general_logs = function(log_id)
  {
    var id=1;
    if(log_id == 0 && $("#general_search").val()!=0)
    {
      id = $("#general_search").val();
    }
    else{
      id = log_id; 
    }
    $.ajax({
      type: "GET",
      dataType: "json",
      url: '/admin/general_log/'+id,
      success: function(data){
      $('#pto_company_name').text(""+data.data.company_name);
      $('#pto_company_domain').text(""+data.data.company_domain);
      $('#pto_action').text(""+data.data.action);
      $('#pto_created_at').text(""+data.created_date);
      $('#pto_result').text(""+data.data.result);
      $("#general_href").attr('href', "/admin/general_log/"+data.data.timestamp)
      $('#general_hidden').click();
      },
      error: function(data) {
        alert("Unable To Found the Record of Given ID!");
      }
    });
  }

  window.show_integration_logs = function(log_id)
  {
    var id=1;
    if(log_id == 0 && $("#integ_search").val()!=0)
    {
      id = $("#integ_search").val();  
    }
    else{
      id = log_id; 
    }
    $.ajax({
      type: "GET",
      dataType: "json",
      url: '/admin/integration_log/'+id,
      success: function(data){
      $('#integ_company_name').text(""+data.data.company_name);
      $('#integ_company_domain').text(""+data.data.company_domain);
      $('#integ_integration').text(""+data.data.integration);
      $('#integ_request').text(""+data.data.request);
      $('#integ_response').text(""+data.data.response);
      $('#integ_action').text(""+data.data.action);
      $('#integ_status').text(""+data.data.status);
      $('#integ_created_at').text(""+data.created_date);
      $("#integ_href").attr('href', "/admin/integration_log/"+data.data.timestamp)
      $('#integ_hidden').click();
      },
      error: function(data) {
        alert("Unable To Found the Record of Given ID!");
      }
    });
  }
  

  window.show_api_logs = function(log_id)
  {
    var id=1 ;
    if(log_id== 0 && $("#api_search").val()!=0)
    {
      id = $("#api_search").val();
    }
    else{
      id = log_id; 
    }
    $.ajax({
      type: "GET",
      dataType: "json",
      url: '/admin/api_log/'+id,
      success: function(data){
      $('#modal_id').text(""+data.data.timestamp);
      $('#api_company_name').text(""+data.data.company_name);
      $('#api_company_domain').text(""+data.data.company_domain);
      $('#api_data_received').text(""+data.data.data_received);
      $('#api_end_point').text(""+data.data.end_point);
      $('#api_location').text(""+data.data.location);
      $('#api_message').text(""+data.data.message);
      $('#api_status').text(""+data.data.status);
      $('#api_created_at').text(""+data.created_date);
      $("#api_href").attr('href', "/admin/api_log/"+data.data.timestamp)
      $('#api_hidden').click();
      },
      error: function(data) {
        alert("Unable To Found the Record of Given ID!");
      }
    });
  }
  window.show_webhook_logs = function(log_id)
  {
    var id=1 ;
    if(log_id== 0 && $("#webhook_search").val()!=0)
    {
      id = $("#webhook_search").val();
    }
    else{
      id = log_id; 
    }
    $.ajax({
      type: "GET",
      dataType: "json",
      url: '/admin/webhook_log/'+id,
      success: function(data){
      $('#modal_id').text(""+data.data.timestamp);
      $('#webhook_company_name').text(""+data.data.company_name);
      $('#webhook_company_domain').text(""+data.data.company_domain);
      $('#webhook_integration').text(""+data.data.integration);
      $('#webhook_data_received').text(""+data.data.data_received);
      $('#webhook_action').text(""+data.data.action);
      $('#webhook_location').text(""+data.data.location);
      $('#webhook_error_message').text(""+data.data.error_message);
      $('#webhook_status').text(""+data.data.status);
      $('#webhook_created_at').text(""+data.created_date);
      $("#webhook_href").attr('href', "/admin/webhook_log/"+data.data.timestamp)
      $('#hidden_button').click();
      
      },
      error: function(data) {
        alert("Unable To Found the Record of Given ID!");
      }
    });
  }
  
  window.show_papertrail_logs = function(log_id) {
    var id = log_id;
    if (log_id == 0 && $('#papertrail_search').val() != 0) {
      id = $('#papertrail_search').val();
    }
    $.ajax({
      type: 'GET',
      dataType: 'json',
      url: '/admin/papertrail_log/' + id,
      success: function(data) {
        $('#modal_id').text('' + data.data.id);
        $('#papertrail_company_name').text(data.company_name);
        $('#papertrail_what').text('' + data.data.event + ' ' + data.data.item_type);
        $('#papertrail_who').text(data.who);
        $('#papertrail_when').text(data.when);
        $('#papertrail_original_value').text(JSON.stringify(data.original_values));
        $('#papertrail_new_value').text(JSON.stringify(data.new_values));
        $('#papertrail_href').attr('href', '/admin/papertrail_log/' + data.data.id);
        $('#hidden_button').click();
      },
      error: function(data) {
        alert('Unable To Find the Record of Given ID!');
      }
    });
  }

  window.export_loggings = function(log_type) {
    company_name = getElementValue('company_name')
    status = getElementValue('status')
    date_from = getElementValue('date_from')
    date_to = getElementValue('date_to')
    
    if (['IntegrationLogging'].includes(log_type)) {
      integration = getElementValue('integration')
      request = getElementValue('request')
      response = getElementValue('response')
      actions = getElementValue('actions')
      params = { company_name: company_name, integration: integration , status: status, request: request, response: response, actions: actions, date_from: date_from, date_to: date_to }
    } else if (['SaplingApiLogging'].includes(log_type)) {
      end_point = getElementValue('end_point')
      data_received = getElementValue('data_received')
      message = getElementValue('message')
      params = { company_name: company_name, status: status, end_point: end_point, data_received: data_received, message: message, date_from: date_from, date_to: date_to}
    } else if (['WebhookLogging'].includes(log_type)) {
      integration = getElementValue('integration')
      actions = getElementValue('actions')
      error_message = getElementValue('error_message')
      data_received = getElementValue('data_received')      
      params = { company_name: company_name, integration: integration , status: status, error_message: error_message, data_received: data_received, actions: actions, date_from: date_from, date_to: date_to }
    }

    $.ajax({
      type: 'GET',
      dataType: 'json',
      url: '/admin/export_loggings',
      data: { loggings_type: log_type, params: params },
    });
  }

  function getElementValue(key) {
    return document.getElementById(key).value
  }

});
