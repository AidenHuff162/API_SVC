namespace :templates do

  desc "Update Notification Tokens"
  task update_notification_tokens: :environment do
    EmailTemplate.where(email_type: "new_buddy").update_all(email_to: '<p><span class="token" contenteditable="false" unselectable="on" data-name="Buddy Email">Buddy Email</span></p>')
    EmailTemplate.where(email_type: "new_manager_form").update_all(email_to: "<p><span class=\"token\" contenteditable=\"false\" unselectable=\"on\" data-name=\"Manager Email\">Manager Email</span>‌</p>")
    EmailTemplate.where(email_type: "new_manager").update_all(email_to: "<p><span class=\"token\" contenteditable=\"false\" unselectable=\"on\" data-name=\"Manager Email\">Manager Email</span>‌</p>")
  puts "Tokens Updated"
  end
end
