//= require jquery
//= require datatables
//= require rails-ujs
//= require turbolinks
// = require modal

$(document).on('turbolinks:load', function(){
  $("table[role='datatable']").each(function(){
      $(this).dataTable({
        serverSide: true,
        pagingType: "simple",
        searching: false,
        scrollX:   true,
        processing: true,
        bSort: false,
        ajax: {
          url: $(this).data('url'),
          data: function (d) {
            d.company_name   = $('#company_name').val();
            d.company_domain = $('#company_domain').val();
            d.integration    = $('#integration').val();
            d.actions        = $('#actions').val();
            d.request        = $('#request').val();
            d.response       = $('#response').val();
            d.status         = $('#status').val();
            d.error_message  = $('#error_message').val();
            d.location       = $('#location').val();
            d.data_received  = $('#data_received').val();
            d.module         = $('#module').val();
            d.date_to        = $('#date_to').val();
            d.date_from      = $('#date_from').val();
            d.result         = $('#result').val();
            elements = document.getElementsByClassName('paginate_button')
            for(var i = 0; i < elements.length; i++){ 
              elements[i].classList.add('disable_button');
            }     
          }
        },
        "drawCallback": function( settings ) {
          elements = document.getElementsByClassName('paginate_button')
          for(var i = 0; i < elements.length; i++){ 
            elements[i].classList.remove('disable_button');
          }     
        }

     });
  });
});

