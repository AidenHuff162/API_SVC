module AddressManager
  class CountryStatesRetriever < ApplicationService
    def initialize(company, country_id)
      country = Country.find(country_id)

      @active_integrations = company.active_integration_names
      @country_name = country.name.downcase
      @states = country.states.ascending(:name)
    end

    def call
      serializer = "StateSerializer::#{serializer_type}".constantize
      ActiveModelSerializers::SerializableResource.new(integration_based_states, each_serializer: serializer).serializable_hash
    end

    private

    attr_reader :active_integrations, :country_name, :states

    def integration_based_states
      if @active_integrations.include?('namely') && @country_name == 'ireland'
        ireland_county_ids = %w[CW CN CE C DL D G KY KE KK LS LM LK LD LH MO MH MN OY RN SO TA WD WH WX WW]
        return @states.where(key: ireland_county_ids)
      end

      return @states.where.not(name: 'London') if @active_integrations.include?('bamboo_hr')

      @states
    end

    def integration_with_country?
      return ['united states'].include?(@country_name) if @active_integrations.include?('paylocity')
      return ['united states', 'canada', 'australia'].include?(@country_name) if @active_integrations.include?('bamboo_hr')
      return ['united states', 'canada'].include?(@country_name) if !(@active_integrations & %w[adp_wfn_us adp_wfn_can trinet]).empty?

      false
    end

    def serializer_type
      integration_with_country? ? 'WithKey' : 'WithName'
    end
  end
end