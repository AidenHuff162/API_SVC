class WebhookEvent < ApplicationRecord
  belongs_to :company
  belongs_to :webhook
  belongs_to :triggered_by, class_name: 'User'
  belongs_to :triggered_for, class_name: 'User'

  enum status: { succeed: 0, failed: 1, pending: 2 }

  scope :with_descending_order, -> { order(triggered_at: :desc) }

  after_create :set_event_id
  after_commit :execute_event, on: :create

  def self.get_formatted_date_time date, current_company
    date = date.in_time_zone(current_company.time_zone) if current_company.time_zone.present?
    get_date = TimeConversionService.new(current_company).perform(date.to_date) rescue ''
    get_time = date.strftime("%H:%M") rescue ''
    get_date + ' ' + get_time
  end

  private

  def set_event_id
    update_column(:event_id, generate_unique_event_id)
  end

  def generate_unique_event_id
    "event_#{SecureRandom.uuid}-#{id}#{Time.now.to_i}"
  end

  def execute_event
    WebhookEvents::ExecuteWebhookEventJob.perform_async(company_id, id)
  end
end
