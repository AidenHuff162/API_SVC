class AddStagesInWebhook < ActiveRecord::Migration[5.1]
  def change
    add_column :webhooks, :configurable, :jsonb
  end
end
