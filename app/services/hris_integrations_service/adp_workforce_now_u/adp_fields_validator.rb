module HrisIntegrationsService
  module AdpWorkforceNowU
    module AdpFieldsValidator

      def validate_name(user_name)
        user_name&.match?(/^$|^[a-zA-Z0-9]([-' .a-zA-Z0-9])*[-'.a-zA-Z0-9]?$/) ? user_name : nil
      end

      def validate_date(date)
        date&.match?(/^(((19|20|21)\d\d)-(0?[1-9]|1[012])-(0?[1-9]|[12]\d|3[01]))?$/) ? date : nil
      end

      def validate_email(email)
        email_regex = /^[A-Za-z0-9_%+-^']+(\.[A-Za-z0-9_%+-^']+)*@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{1,6}$/
        email&.match?(email_regex) ? email : nil
      end

      def validate_marital_status(marital_status)
        ['C', 'D', 'E', 'L', 'M', 'P', 'S', 'W'].include?(marital_status) ? marital_status : nil
      end

      def validate_race_id_method(race_id_method)
        ['SID', 'VID'].include?(race_id_method) ? race_id_method : nil
      end

      def validate_gender(gender)
        ['M', 'F', 'N'].include?(gender) ? gender : nil
      end

      def validate_race_ethnicity(race_ethnicity)
        ['1', '2', '3', '4', '5', '6', '9'].include?(race_ethnicity) ? race_ethnicity : nil
      end

      def validate_tax_values(tax)
        tax_regex = /\d{9}|\d{3}-\d{2}-\d{4}/
        if tax.present? && ['SSN', 'SIN'].include?(tax[:tax_type])
          tax[:tax_value] = tax[:tax_value]&.match?(tax_regex) ? tax[:tax_value] : nil
        end
        tax
      end

      def validate_itin_value(itin_number)
        itin_number&.match?(/\d{3}-\d{2}-\d{4}/) ? itin_number : nil
      end

      def validate_phone(phone)
        phone_number = "+#{phone[:country_dialing]}#{phone[:area_code]}#{phone[:phone]}"
        parsed_number = Phonelib.parse(phone_number)

        parsed_number.valid? ? phone : phone.transform_values! { |value| nil }
      end
    end
  end
end
