module ImportData
  class ImportDataJob
    include Sidekiq::Worker
    sidekiq_options queue: :upload_user_data, retry: false, backtrace: true

    def perform(params, options)
      import_method = params['import_method']
      company = Company.find_by(id: options['company_id'])
      current_user = company&.users&.find_by(id: options['current_user_id'])
      return unless company.present? || current_user.present?

      args = { company: company, data: params['data'], current_user: current_user,
              upload_date: options['upload_date'], import_method: import_method,
              table_name: params['table_name'], is_tabular: params['is_tabular'] }
      
      "::ImportUsersData::#{get_importer_name(import_method)}".constantize.new(args).perform
    end

    private

    def get_importer_name(import_method)
      {
      'Custom Group' => 'UploadGroupData',
      'PTO balances' => 'UploadPtoBalance',
      'PTO requests' => 'UploadPtoRequests',
      'Pending hires' => 'UploadPendingHire',
      'Custom Holiday' => 'UploadHolidayData',
      'Create Pending hires' => 'UploadPendingHire',
      'Update Permission' => 'UploadPermissionData',
      }.fetch(import_method, 'UploadProfileData')
    end
  end
end
