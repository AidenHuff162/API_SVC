module ImportUsersData
  class Helper
    CHECK_EMAIL_REGEXP = Devise.email_regexp # this is being used to check csv injection

    def file_storage_path
      Rails.env.development? || Rails.env.test? ? Rails.root.join('tmp') : File.join(Dir.home, 'www/sapling/shared/')
    end

    def add_user_error_to_row(entry, error_message)
      entry['upload error message'] = error_message
    end

    def create_user_error_csv(data, **kwargs)
      file = File.join(file_storage_path, "#{kwargs[:company].subdomain}_defective_#{kwargs[:section_name]}_#{rand(1000)}.csv")

      CSV.open(file, 'w', write_headers: true, headers: prepare_column_header(kwargs[:header])) do |writer|
        data.try(:each) do |item|
          next unless item['upload error message']

          writer << item.try(:map) { |_key, value| value ? handle_csv_values(value) : '' }
        end
      end
      file
    end

    def prepare_column_header(csv_header)
      column_headers = csv_header.push('upload error message').uniq
      column_headers.map { |h| h.present? ? h.titleize : '' }
    end

    def handle_csv_values(value)
      value.present? && ((value[0] == '0' && !value.include?('/')) ||
      check_if_potential_csv_injection_threat?(value)) ? "'#{value}'" : value.to_s
    end

    def check_if_potential_csv_injection_threat?(value)
      value[0].to_s.match(/[-+=@|]/).present? ||
        (value.to_s.match(/[-+=|]/).present? &&
        value.to_s.match(/[0-9]/).present? &&
        !check_if_email?(value) &&
        !check_if_url?(value))
    end

    def check_if_email?(email)
      email =~ CHECK_EMAIL_REGEXP
    end

    def check_if_url?(url)
      url = begin
        URI.parse(url)
      rescue StandardError
        false
      end
      url.is_a?(URI::HTTPS) || url.is_a?(URI::HTTP)
    end

    def downcase_and_to_array(value)
      value.downcase.split(',').map { |v| v.strip }
    end

    def send_feedback_email(**kwargs)
      data, headers, section_name, company = kwargs.values_at(:data, :headers, :section_name, :company)
      invalid_entries, upload_date, first_name, email = kwargs.values_at(:invalid_entries, :upload_date, :first_name, :email)

      file = create_user_error_csv(data, { header: headers, section_name: section_name, company: company }) if data && invalid_entries.size > 0
      args = [ company, email, first_name, invalid_entries, data.count, upload_date, file, section_name ]
      UserMailer.upload_user_feedback_email(*args).deliver_now!
      file && File.exist?(file) ? File.delete(file) : true
    end
  end
end
