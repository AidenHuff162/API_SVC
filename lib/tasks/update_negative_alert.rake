namespace :alerts do

  desc "Update Negative Time off balance alert"
  task update_negative_alert: :environment do
    CustomEmailAlert.where(alert_type: "negative_balance", body: nil).update_all(body: "<p><span class=\"token\" contenteditable=\"false\" unselectable=\"on\" data-name=\"Display Name\">Display Name</span>‌ a <span class=\"token\" contenteditable=\"false\" unselectable=\"on\" data-name=\"Job Title\">Job Title</span>‌ in <span class=\"token\" contenteditable=\"false\" unselectable=\"on\" data-name=\"Location\">Location</span>‌, recently requested time off&#40;<span class=\"token\" contenteditable=\"false\" unselectable=\"on\" data-name=\"Policy Name\">Policy Name</span>‌&#41; &#97;&#110;&#100; now has a negative balance.</p>")
  puts "Alert Updated"
  end
end
