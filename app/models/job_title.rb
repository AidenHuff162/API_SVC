class JobTitle < ApplicationRecord
  has_paper_trail
  belongs_to :company
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)
  
  def self.sync_adp_option_and_code(company, option, code, environment)
    return unless option.present? && code.present? && environment.present?

    if environment == 'US'
      company.job_titles.where('name ILIKE ? OR adp_wfn_us_code_value = ?', option, code).first_or_create(name: option)
        .update(name: option, adp_wfn_us_code_value: code)
    elsif environment == 'CAN'
      company.job_titles.where('name ILIKE ? OR adp_wfn_can_code_value = ?', option, code).first_or_create(name: option)
        .update(name: option, adp_wfn_can_code_value: code)
    end
  end
end
