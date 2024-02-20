class State < ApplicationRecord
  has_paper_trail
  include Orderable

  belongs_to :country

  INTEGRATIONS = %w[paylocity bamboo adp_wfn_profile_creation_and_bamboo_two_way_sync adp_wfn_us
                    adp_wfn_can adp_wfn_us_and_can trinet]
  COUNTRY_INTEGRATIONS_FOR_KEY = {
    'United States': INTEGRATIONS,
    'Canada': INTEGRATIONS - %w[paylocity],
    'Australia': INTEGRATIONS - %w[paylocity adp_wfn_us adp_wfn_can adp_wfn_us_and_can trinet]
  }

  def state_key_required?(integration_type)
    return false unless country.present?

    COUNTRY_INTEGRATIONS_FOR_KEY[country.name.to_sym]&.include?(integration_type)
  end
end
