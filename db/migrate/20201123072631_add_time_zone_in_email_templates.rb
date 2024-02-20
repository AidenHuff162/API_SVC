class AddTimeZoneInEmailTemplates < ActiveRecord::Migration[5.1]
  def change
  	change_column_default :email_templates, :schedule_options, {"due"=>nil, "date"=>nil, "time"=>nil, "duration"=>nil, "send_email"=>0, "relative_key"=>nil, "duration_type"=>nil, "to"=>nil, "from"=>nil, "set_onboard_cta"=>false, "time_zone"=>nil}
  end
end
