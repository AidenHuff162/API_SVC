class RequestedField < ApplicationRecord
  acts_as_paranoid
  
  belongs_to :custom_field
  belongs_to :custom_section_approval

  enum field_type: { short_text: 0, long_text: 1, multiple_choice: 2, confirmation: 3, mcq: 4, social_security_number: 5, date: 6, address: 7, phone: 8, simple_phone: 9, number: 10, coworker: 11,  multi_select: 12, employment_status: 13, currency: 14, social_insurance_number: 15, tax: 16, national_identifier: 17 }

end
