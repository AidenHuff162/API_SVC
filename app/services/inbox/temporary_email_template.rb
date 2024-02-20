module Inbox
  class TemporaryEmailTemplate < ApplicationService
    attr_reader :dates, :collection

    def initialize(collection, dates)
      @collection = collection
      @dates = dates
    end

    def call
      perform
    end

    private

    def perform
      templates = []
      collection.results.each do |template|
        email_template = template.dup
        email_template.assign_attributes(is_temporary: true, name: get_name(email_template))
        set_attachments(email_template, template)
        get_date(email_template)
        email_template.schedule_options['to'] = 'personal' if email_template.company.provisiong_account_exists?
        email_template.save!
        templates << email_template
      end

      templates
    end

    def get_name(email_template)
      name = ActionView::Base.full_sanitizer.sanitize(email_template.name)
      "#{Time.now.to_i}---#{name}" 
    end 
   
   def set_attachments(new_tempalte, template)
     template.attachments.each do |attachment|
        file = Attachments::UploadAttachments.perform(attachment, 'EmailTemplate')
        new_tempalte.attachments.push file if file.present?
      end  
    end 

   def get_date(new_tempalte)
     dates.each do |date|
      date =  date.try(:to_date)
      
       message = check_valid_schedule_options(new_tempalte, date)
       new_tempalte.schedule_options['message'] = message if message.present?
     end
    end

    def check_valid_schedule_options(template, date)
      message = start_date_template(template, date)
   
      date = calculate_date(template, date) if message.nil?

      if ['start date'].include?(template.schedule_options['relative_key']) && date && date < template.company.time.to_date
        message = 'Selected date is in the past'
      end
      
      message
    end

    def calculate_date(template, date)
      if date && ['before', 'after'].include?(template.schedule_options['due'])
        symbol = template.schedule_options['due'] == 'before' ?  '-' : '+'
        date = date.send(symbol, eval(template.schedule_options["duration"].to_s + '.' + template.schedule_options["duration_type"]) ) 
      end

      date
    end

    def start_date_template(template, date)
      if ['start date', 'anniversary'].include?(template.schedule_options['relative_key'])
        message = 'Set a start date first for this new hire or change the scheduled date' if date == nil
      end
    end
  end 
end




