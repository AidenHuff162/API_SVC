class BswiftService::Main

  def initialize(company)
    @company = company
    @integration = @company.integration_instances.find_by_api_identifier('bswift')
    hires_data = fetch_hires
    terminations_data = fetch_terminations(hires_data.ids)
    updates_data = fetch_updates(hires_data.ids.concat(terminations_data.ids))
    @employees = (hires_data + terminations_data + updates_data)
    @employees = IntegrationsService::Filters.call((hires_data + terminations_data + updates_data), @integration) if @company.subdomain != 'vsco'
  end

  def perform
    execute_integration
  end

  private

  def fetch_hires
    @company.users.where(sent_to_bswift: false).where.not(current_stage: [0, 1, 7, 8]) rescue User.none
  end

  def fetch_terminations(hire_data_ids)
    @company.users.where(sent_to_bswift: true, is_terminated_in_bswift: false, current_stage: 7, state: 'inactive').where.not(id: hire_data_ids, termination_date: nil) rescue User.none
  end

  def fetch_updates(hire_termination_ids)
    @company.users.updated_in_days(1).where(sent_to_bswift: true).where.not(id: hire_termination_ids) rescue User.none
  end

  def execute_integration
    return if @employees.empty? || !@integration
    filename, num_rows, written_user_ids = BswiftService::WriteCSV.new(@company, @integration, @employees).perform
    if num_rows > 0
      BswiftService::SendToS3.new(filename, @company).perform
      status = BswiftService::PushCsv.new(filename, @integration, @company).perform
      # update sent_to_bswift flag here of relevant users if CSV was sent successfully
      if status != -1
        @company.users.where(id: written_user_ids).update_all(sent_to_bswift: true)
        @company.users.where(id: written_user_ids, current_stage: 7).where.not(termination_date: nil).update_all(is_terminated_in_bswift: true)
      end
    end
    File.delete(filename) if File.exist?(filename)
  end
end
