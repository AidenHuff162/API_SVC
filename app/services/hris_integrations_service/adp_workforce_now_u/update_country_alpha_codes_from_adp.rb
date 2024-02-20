class HrisIntegrationsService::AdpWorkforceNowU::UpdateCountryAlphaCodesFromAdp
  attr_reader :company, :adp_wfn_api

  delegate :create_loggings, to: :helper

  def initialize(adp_wfn_api)
    @adp_wfn_api = adp_wfn_api
    @company = adp_wfn_api&.company
  end

  def sync
    sync_country_alpha_codes('Worked in Country')
  end

  private

  def sync_country_alpha_codes(field_name)
    begin
      alpha_codes = ISO3166::Country.all.collect(&:alpha2)
      return unless alpha_codes.present? && field_name.present?
      
      alpha_codes.each do |code|
        CustomFieldOption.create_custom_field_option(@company, field_name, code)
      end
    rescue Exception => e
      log(500, "UpdateCountryAlphaCodeFromAdp #{enviornment} - ERROR", { message: e.message  })
    end
  end

  def helper
    HrisIntegrationsService::AdpWorkforceNowU::Helper.new
  end

  def log(status, action, result)
    create_loggings(company, "ADP Workforce Now - #{enviornment}", status, action, result)
  end
end
