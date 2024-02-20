class Logging < ApplicationRecord
  has_paper_trail
  belongs_to :integration
  belongs_to :company

  #TODO: Will be uncommented in future
  # around_save :depreciate_method, if: Proc.new { Rails.env.development?.blank? }
  # around_destroy :depreciate_method, if: Proc.new { Rails.env.development?.blank? }

  def self.api_request(query)
    where("array_to_string(loggings.api_request, ', ') ILIKE ?", "%#{query}%")
  end

  ransacker :result do |parent|
    Arel.sql "(loggings.result)::text"
  end

  #TODO: Will be uncommented in future
  # def depreciate_method
  #   puts 'halting execution.. table depreciated!'
  # end
end
