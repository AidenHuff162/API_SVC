class HrisIntegrationsService::Workday::ManageSaplingInWorkday < ApplicationService
  include HrisIntegrationsService::Workday::Logs
  include HrisIntegrationsService::Workday::Exceptions
  attr_reader :user, :action, :field_names, :doc_file_hash, :company

  def initialize(user:, **kwargs)
    @user, @company = user, user.company
    @action, @doc_file_hash, @field_names = kwargs.values_at(:action, :doc_file_hash, :field_names)
  end

  def call
    begin
      return if (integration = user.company.get_integration('workday')).blank?

      validate_creds_presence!(integration)
      validate_worker_subtype!(user)
      execute
    rescue Exception => @error
      error_log("Unable to sync user (#{user.id}) from Sapling to Workday", {},
                { action: action, doc_file_hash: doc_file_hash, field_names: field_names })
    end
  end

  private

  def execute
    case action
    when 'update'
      attrs = { doc_file_hash: doc_file_hash }
      HrisIntegrationsService::Workday::Update::SaplingInWorkday.call(user, field_names, attrs)
    when 'terminate'
      HrisIntegrationsService::Workday::Terminate::SaplingInWorkday.call(user)
    end
  end

end
