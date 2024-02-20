module HrisIntegrationsService
  module AdpWorkforceNowU
    module AdpAddressFieldsValidator

      def validate_address(address)
        (validate_address_line(address[:line1]) || validate_address_line(address[:line2])) &&
          validate_city(address[:city]) &&
          validate_zip(address[:zip], address[:country]) ? address : address.transform_values! { |value| nil }
      end

      def validate_address_line(line)
        line&.match?(/^$|^[a-zA-Z0-9#,'.\/\\ -]([a-zA-Z0-9 #,'.\/\\-]*[a-zA-Z0-9#,'.\/\\-])?$/)
      end

      def validate_city(city)
        city&.match?(/^$|^[a-zA-Z0-9#,'.\/\\ -]([a-zA-Z0-9 #,'.\/\\-]*[a-zA-Z0-9#,'.\/\\-])?$/)
      end

      def validate_zip(postal_code, country_name)
        zip_code_regex = get_country_based_zip_pattern(country_name)
        postal_code&.match?(zip_code_regex) if zip_code_regex.present?
      end

      def get_country_based_zip_pattern(country_name)
        group1_countries = ['Australia', 'Austria', 'Bangladesh', 'Belgium', 'Bulgaria', 'Denmark', 'Hungary', 'Luxembourg', 'New Zealand',
                            'Norway', 'Philippines', 'South Africa', 'Switzerland', 'Venezuela']
        group2_countries = ['Algeria', 'France', 'Germany', 'Indonesia', 'Italy', 'Malaysia', 'Mexico', 'Mexico', 'Peru', 'Spain',
                            'Taiwan', 'Thailand', 'Trinidad and Tobago', 'Turkey', 'Virgin Islands', 'Dominican Republic']
        group3_countries = ['China', 'Colombia', 'Kazakhstan', 'South Korea', 'Russia', 'Singapore', 'Vietnam']

        if group1_countries.include?(country_name)
          /^([0-9]{4})$/
        elsif group2_countries.include?(country_name)
          /^([0-9]{5})$/
        elsif group3_countries.include?(country_name)
          /^([0-9]{6})$/
        else
          get_non_generic_countries_zip_pattern(country_name) || /^([0-9]{5}[-][0-9]{4}|[0-9]{9}|[0-9]{5})$/
        end
      end

      def get_non_generic_countries_zip_pattern(country_name)
        country_based_zip_code_hash = {
          'Argentina': /^([a-zA-Z][0-9]{4}[a-zA-Z]{3})$/,
          'Brazil': /^([0-9]{5}[-][0-9]{3})$/,
          'Czechia': /^([0-9]{3}[ ][0-9]{2})$/,
          'India': /^([0-9]{6}|[0-9]{3}[ ][0-9]{3})$/,
          'Ireland': /^([a-zA-Z0-9]{3}[ ][a-zA-Z0-9]{4})$/,
          'Japan': /^([0-9]{3}[-][0-9]{4})$/,
          'Lithuania': /^([a-zA-Z]{2}[-][0-9]{5})$/,
          'Netherlands': /^([0-9]{4}[ ][a-zA-Z]{2})$/,
          'Poland': /^([0-9]{5}|[0-9]{2}[-][0-9]{3})$/,
          'Portugal': /^([0-9]{4}[-][0-9]{3}|[0-9]{4}[ ][0-9]{3})$/,
          'SaintLucia': /^([0-9]{4}[ ][0-9]{4})$/,
          'Slovakia': /^([0-9]{5}|[0-9]{3}[ ][0-9]{2})$/,
          'Sweden': /^([0-9]{5}|[0-9]{3}[ ][0-9]{2})$/,
          'UnitedKingdom': /^([a-zA-Z]{2}[0-9][a-zA-Z][ ][0-9][a-zA-Z]{2}|[a-zA-Z][0-9][a-zA-Z][ ][0-9][a-zA-Z]{2}|[a-zA-Z][0-9][ ][0-9][a-zA-Z]{2}|[a-zA-Z][0-9]{2}[ ][0-9][a-zA-Z]{2}|[a-zA-Z]{2}[0-9][ ][0-9][a-zA-Z]{2}|[a-zA-Z]{2}[0-9]{2}[ ][0-9][a-zA-Z]{2})$/,
          'UnitedStates': /^([0-9]{5}[-][0-9]{4}|[0-9]{9}|[0-9]{5})$/,
          'Canada': /^([a-zA-Z][0-9][a-zA-Z][0-9][a-zA-Z][0-9]|[a-zA-Z][0-9][a-zA-Z][ ][0-9][a-zA-Z][0-9])$/,
          'PuertoRico': /^([0-9]{5}[-][0-9]{4}|[0-9]{9}|[0-9]{5})$/
        }.with_indifferent_access
        country_name = country_name.gsub(' ', '')
        country_based_zip_code_hash[country_name]
      end
    end
  end
end
