module General
  def confirm
    page.execute_script <<-JS
      $('.confirm-dialog .btn.confirm').click()
    JS
    page.driver.browser.switch_to.alert.accept
  rescue NoMethodError
    # Phantomjs confirms all alerts by default
    true
  end

  def navigate_to(path)
    sleep 1
    visit path
  end

  def wait_for_condition
    counter = 0
    step = 0.5
    condition_result = yield

    while !condition_result && counter <= Capybara.default_max_wait_time
      sleep step
      condition_result = yield
      counter += step
    end
  end

  def wait(time)
    sleep(time)
  end

  def clear_mail_queue
    ActionMailer::Base.deliveries.clear
  end

  def wait_for_element(selector)
    wait_for_condition { page.has_selector?(selector, wait: false) }
  end

  def wait_all_requests
    page.evaluate_script('jQuery.active').zero?
    page.evaluate_script('$.active') == 0
    wait(1)
  end

  def add_to_date_picker(field_name, date)
    page.execute_script("$('[name=\"#{field_name}\"] input').val('#{date}')")
  end

  def choose_item_from_dropdown(field_name, item_text)
    find("md-select[name='#{field_name}']").trigger('click')
    find('md-select-menu md-content md-option div', text: item_text, match: :first).trigger('click')
  end

  def choose_item_from_multi_select_dropdown(field_name, item_text)
    find("md-select[name='#{field_name}']").trigger('click')
    find("md-option[value='#{item_text}']")
  end

  def choose_first_item_from_dropdown(field_name)
      find("md-select[name='#{field_name}']").trigger('click')
      sleep(1)
      first('[role="option"]').trigger('click')
  end

  def choose_item_from_autocomplete(field_name, item_text)
     wait_all_requests
     find("[name='#{field_name}']", match: :first).trigger('click')
     find("[name='#{field_name}'] input", match: :first).native.send_keys(*item_text.chars)
     wait_all_requests
     find('md-autocomplete-parent-scope', text: item_text, match: :first).trigger('click')
  end

  def choose_item_from_autocomplete_smart(field_name, item_text)
     wait_all_requests
     find("[name='#{field_name}']", match: :first).trigger('click')
     find("[name='#{field_name}']", match: :first).native.send_keys(*item_text.chars)
     wait_all_requests
     find('md-autocomplete-parent-scope', text: item_text, match: :first).trigger('click')
  end


  def attach_ng_file(element_key, file, controller:, element_base: nil)
    page.execute_script <<-JS
      var element = document.getElementById('fake-file-input');
      if (!element) {
        window.$('<input/>').attr({ id: 'fake-file-input', type: 'file' }).appendTo('body');
      }
    JS

    page.attach_file('fake-file-input', file)

    page.execute_script <<-JS
      var element = document.getElementById('fake-file-input');
      var file = element.files[0];
      var ctrlKey = '#{controller}_ctrl';
      var ctrl = null;
      $('.ng-scope').each(function(i, el) {
        var ctrlScope = angular.element(el).scope();
        if (ctrlScope[ctrlKey]) {
          ctrl = ctrlScope[ctrlKey];
        }
      });
      var base = #{element_base ? "ctrl.#{element_base}" : "null"};
      ctrl.upload('#{element_key}', file, [], base);
    JS

    wait_all_requests
  end

def alert_present?
  begin
    session.driver.browser.switch_to.alert
     true
  rescue
     return false
  end
end

  def scroll_to(element)
    script = <<-JS
     arguments[0].scrollIntoView(true);
    JS
    Capybara.current_session.driver.browser.execute(script)
  end
end

def reload_page
  page.evaluate_script("window.location.reload()")
end
