class ApiLogging < ApplicationRecord
  has_paper_trail
  belongs_to :company

  around_save :depreciate_method, if: Proc.new { Rails.env.development?.blank? && Rails.env.test?.blank? }
  around_destroy :depreciate_method, if: Proc.new { Rails.env.development?.blank? && Rails.env.test?.blank? }

  def depreciate_method
    puts 'halting execution.. table depreciated!'
  end
end