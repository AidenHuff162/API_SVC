class TeamSpiritService::Main
  delegate :logging, to: :helper_service

  def initialize(integration)
    @company = integration.company
    @integration = integration
  end

  def perform
    return if company.blank? || integration.blank?
    send_file('starters')
    send_file('leavers')
    send_file('changes')
  end

  private
  attr_reader :company, :integration

  def send_file(user_group)
    begin
      group_method = case user_group
      when 'starters'
        'hired_in_a_week'
      when 'leavers'
        'offboarded_in_a_week'
      when 'changes'
        'updated_in_a_week'
      end
      users = company.users.send(group_method)
      return if users.blank?
      puts "================= group method ====================="
      puts "============#{group_method} =========================="
      puts "======================================"
      puts "===============users======================="
      puts "===============#{users.map(&:email)}======================="
      puts "======================================"

      filename, num_rows = TeamSpiritService::WriteCSV.new(company, integration, users).perform(user_group)
      if num_rows > 0
        TeamSpiritService::SendToS3.new(filename, company).perform
        TeamSpiritService::PushCsv.new(filename, integration, company).perform
      end
    rescue Exception => e
      logging.create(company, 'TeamSpirit', "Send file:#{filename} - Failure", nil, { error: e.to_s }.to_json, 500)
    end
    File.delete(filename) if File.exist?(filename)
  end

  def helper_service
    TeamSpiritService::Helper.new
  end
end
