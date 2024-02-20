class TeamSpiritService::WriteCSV
  attr_reader :company, :integration, :users
  delegate :can_send_data?, :logging, to: :helper_service

  STARTERS_CHANGERS_HEADERS= ['BANK1', 'BACC', 'ADD1', 'ADD2', 'ADD3', 'ADD4', 'PKBHTYPE', 'BANK2', 'BHOURS', 'BANK3',
                    'EMLWRK', 'CONTSERV', 'ATGCONTY', 'BIRTH', 'BDAYS', 'DEPT', 'RISE', 'EMPCODE', 'ABHEPR', 'FIRST',
                    'CEFTE', 'CEFP', 'HOLENT', 'PKENLK', 'ABHEPR', 'TEL', 'JOBTITLE', 'MAIDEN', 'MSTATUS', 'EMMOB',
                    'NINUM', 'ATGPAYTY', 'METHOD', 'FREQ', 'EMLADD', 'POSTCDE', 'CEPROBPD', 'REPORTID', 'BPAYANN',
                    'SECOND', 'SEX', 'SORTC', 'JOIN', 'SURNAME', 'CEPT', 'TITLE', 'DIVISION', 'PKWPIND', 'LEAVE']

  LEAVERS_HEADERS = ['EMPCODE','LEAVE']

  def initialize(company, integration,  users)
     @company = company
     @integration = integration
     @users =  users
  end

  def perform(user_group)
    filename = "#{user_group}_#{company.id}_#{company.domain}_#{Date.today.to_s}.csv"
    num_rows = 0
    headers_method = user_group == 'leavers' ? user_group : 'starters_changers'
    headers_const = "#{headers_method}_HEADERS".upcase
    headers = TeamSpiritService::WriteCSV.const_get(headers_const)
    begin
      CSV.open(filename, 'w+', write_headers: true, headers: headers) do |writer|
        users.each do |user|
          puts "================"
          puts "=======can send data ========="
          puts "=========#{can_send_data?(integration, user)}======="
          puts "========#{user.email}========"
          next unless can_send_data?(integration, user)
          mapping_method = "build_#{headers_method}_parameter_mappings"
          row_values = TeamSpiritService::DataBuilder.new(TeamSpiritService::ParamsMapper.new.send(mapping_method)).build_csv_data(user, integration)
          next if row_values == -1
          writer << row_values
          num_rows += 1
        end
      end
    rescue Exception => e
      logging.create(company, 'TeamSpirit', "Fetch CSV data for file #{filename} - Failure", nil, { error: e.to_s }.to_json, 500)
    end
    return [filename, num_rows]
  end

  def helper_service
    TeamSpiritService::Helper.new
  end
end
