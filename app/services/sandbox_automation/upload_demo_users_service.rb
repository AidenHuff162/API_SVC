require 'csv'

class SandboxAutomation::UploadDemoUsersService
  def initialize params
    begin
      id = params["id"].to_i rescue nil
      @company = Company.find_by(id: id) if id
    rescue Exception => e
      puts e
    end
  end

  def perform
    upload_standard_users
    upload_tabular_data if @company.is_using_custom_table
  end

  private
  def upload_standard_users
    begin
      url = get_file_url('demo-users.csv')
      CsvUploadUsersJob.perform_async(@company.id, @email, true, url)
    rescue Exception => e
      puts e
    end
  end

  def upload_tabular_data
    params = custom_field_params = {
      company_id: @company.id,
      locks: { all_locks: false, options_lock: false },
      required: false,
      collect_from: :admin
    }
    visa_table = @company.custom_tables.where(name: 'Visa Status').first_or_create!(name: 'Visa Status', custom_table_property: CustomTable.custom_table_properties[:general], is_deletable: false, position: 0, table_type: 'timeline')
    visa_table.custom_fields.where(name: 'Renewal date').first_or_create!(params.merge({ name: 'Renewal date', field_type: CustomField.field_types[:date], position: 2}))
    visa_table.custom_fields.where(name: 'Visa Type').first_or_create!(params.merge({ name: 'Visa Type', field_type: CustomField.field_types[:short_text], position: 3}))
    visa_table.custom_fields.where(name: 'Country').first_or_create!(params.merge({ name: 'Country', field_type: CustomField.field_types[:short_text], position: 4}))

    ['role-information.csv', 'compensation.csv', 'employement-status.csv', 'visa-status.csv'].each do |file_name|
      begin
        url = get_file_url file_name
        CsvUploadUsersJob.perform_async(@company.id, @email, true, url)
      rescue Exception => e
        puts e
      end
    end    
  end

  def get_file_url file_name
    object = Aws::S3::Resource.new(access_key_id: ENV['AWS_ACCESS_KEY'], secret_access_key: ENV['AWS_SECRET_KEY'], region: ENV['AWS_REGION']).bucket(ENV['AWS_BUCKET']).object("demo-assets/users/#{file_name}")
    url = object.presigned_url(:get, expires_in: 60 * 60)
  end
end
