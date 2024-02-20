class AsanaService::CreateTask

  def initialize(receiver)
    @receiver = receiver
    @company = @receiver.company rescue nil
    @integration = @company.integration_instances.find_by(api_identifier: "asana", state: :active) rescue nil
  end

  def perform
    return unless @receiver.present? && @company.present? && @integration.present?
    # look for project with name (that user belongs to?), otherwise create one
    project_id = select_project
    return unless project_id
    # validate that task owner exists on asana
    @receiver.task_user_connections.where(send_to_asana: true, user_id: @receiver.id).each do |tuc|
      @owner = tuc.owner
      @tuc = tuc
      @task = @tuc.task rescue nil
      next unless @task.present? && @owner.present? && validate_users && @owner.asana_id.present?
      asana_task = create_task(project_id)
    end
    @integration.update_column(:synced_at, DateTime.now) if @integration
    true
  end

  private

  def fetch_user
    user = execute_request("https://app.asana.com/api/1.0/users/#{@owner.email || @owner.personal_email}", false)
    if !user || user["errors"].present? || !user["data"].present? || user["data"].class == Array || !user["data"]["gid"].present?
      result = user["errors"].present? ? user["errors"] : "User with email #{@owner.email || @owner.personal_email} could not be fetched from Asana"
      log('Validate User - ERROR', 500, result)
      return false
    else
      @owner.asana_id = user["data"]["gid"]
      @owner.save!
      return true
    end
  end

  def validate_users
    unless @owner.asana_id.present?
      fetch_user
      @owner.reload
      return false unless @owner.asana_id.present?
    end

    user = execute_request("https://app.asana.com/api/1.0/users/#{@owner.asana_id}", false)

    if !user.present? || user["errors"].present?
      result = user["errors"] rescue "User Not Found"
      log('Validate User - ERROR', 500, result)
      return false
    else
      return true
    end
  end

  def select_project
    # get all teams
    workspace = execute_request("https://app.asana.com/api/1.0/workspaces/#{@integration.asana_organization_id}", false)
    if workspace.present? && workspace["errors"].present?
      log('Fetch workspace', 500, workspace)
      return false
    end

    # Non-organization workspaces only contain 1 team
    if workspace && workspace["data"] && workspace["data"]["is_organization"]
      # organizations support multiple teams
      # look for team where name=integration.default_team_name
      # if found, return team_id.  else, return false
      teams = execute_request("https://app.asana.com/api/1.0/organizations/#{@integration.asana_organization_id}/teams?limit=100", false)
      team_id = nil
      teams["data"].each do |team|
        if team["name"] == @integration.asana_default_team
          team_id = team["id"] || team["gid"]
          break
        end
      end

      until team_id.present? || !teams["next_page"]
        teams = execute_request(teams["next_page"]["uri"], false)
        teams["data"].each do |team|
          if team["name"] == @integration.asana_default_team
            team_id = team["id"] || team["gid"]
            break
          end
        end
      end

      unless team_id.present? # could not find team with matching name
        log('Match teams - team not found', 404, teams) if teams.present?
        return false
      end
    elsif workspace && workspace["data"] && workspace["data"]["is_organization"] == false
      team_id = nil
    end


    project_name = "#{@receiver.first_name} #{@receiver.last_name}, #{@receiver.start_date.strftime('%m/%d/%Y')}"
    project_name = project_name.concat(", #{@receiver.location.name}") if @receiver.location.present?
    project_id = nil

    unless team_id
      projects = execute_request("https://app.asana.com/api/1.0/workspaces/#{@integration.asana_organization_id}/projects?limit=100", false)
    else
      projects = execute_request("https://app.asana.com/api/1.0/teams/#{team_id}/projects?limit=100", false)
    end

    if !projects || projects["errors"]
      log('Fetch existing projects', 500, projects) if projects.present?
      return false
    end
    projects["data"].each do |project|
      if project["name"] == project_name
        project_id = project["id"] || project["gid"]
        # return project id if we found a match
        return project_id
      end
    end

    if projects["next_page"].present?
      until !projects["next_page"].present?
        projects = execute_request(projects["next_page"]["uri"], false)
        if !projects || projects["errors"]
          log('Fetch existing projects', 500, projects) if projects.present?
          return false
        end
        projects["data"].each do |project|
          if project["name"] == project_name
            project_id = project["id"] || project["gid"]
            # return project id if we found a match
            return project_id
          end
        end
      end
    end

    # otherwise, create new project
    # look for team if relevant

    post_url = URI::encode("https://app.asana.com/api/1.0/workspaces/#{@integration.asana_organization_id}/projects")
    project_data = { name: project_name }
    if team_id.present?
      project_data = project_data.merge({ team: team_id.to_s })
    end
    created_project = execute_request(post_url, true, { data: project_data })
    if !created_project || !created_project["data"] || created_project["errors"]
      log('Create project - ERROR', 500, created_project) if created_project.present?
      return false
    end
    return created_project["data"]["gid"] || created_project["data"]["id"]
  end

  def create_task(project_id)
    begin
      created_task = nil
      url = URI::encode("https://app.asana.com/api/1.0/tasks")

      name = Nokogiri::HTML(ReplaceTokensService.new.replace_task_tokens(@task.name, @tuc.user, nil, nil, nil, true)).text.gsub("\u200C", "")
      if @task.survey_id
        formatted_description = "<body>This survey task can only be completed in Sapling: <a href=\"https://#{@company.app_domain}/#/survey/#{@tuc.id}\"></a></body>"
      else
        notes = Nokogiri::HTML(ReplaceTokensService.new.replace_task_tokens(@task.description, @tuc.user, nil, nil, nil, true)).to_s

        html = Nokogiri::HTML.parse(notes)
        html.css('[style]').each do |node|
          node.delete 'style'
        end
        html.css('[class]').each do |node|
          node.delete 'class'
        end
        html.css('[target]').each do |node|
          node.delete 'target'
        end
        html.search('//img').each do |node|
          node.remove
        end
        html.search('//iframe').each do |node|
          node.remove
        end
        html.search('//span').each do |node|
          node.remove
        end

        formatted_description = html.at('body').to_s.gsub(/<br>/, '').gsub(/<p>/, "").gsub(/<\/p>/, "").gsub("\u200C", "")
      end
      formatted_description = "<body></body>" if formatted_description == ""
      
      task_data = { data: {
        assignee: @owner.asana_id,
        name: name,
        completed: false,
        due_on: @tuc.due_date,
        projects: [project_id.to_s],
        html_notes: formatted_description,
        workspace: @integration.asana_organization_id
      }}
      created_task = execute_request(url, true, task_data)

      if !created_task || !created_task["data"] || created_task["errors"]
        result = created_task["errors"] rescue "Could Not Create Task"
        log('Create Task - ERROR', 500, result)
        return false
      end
      
      asana_id = created_task["data"]["gid"]
      @tuc.update(asana_id: asana_id, send_to_asana: nil)

      if @task.attachments.present? && Rails.env != "development" && Rails.env != "test"
        @task.attachments.each do |attachment|
          posted_attachment = post_attachment(attachment, created_task["data"]["gid"])
          if !posted_attachment || !posted_attachment["data"] || posted_attachment["errors"]
            result = posted_attachment["errors"] rescue "Could Not Post Attachment"
            log('Post Attachment - ERROR', 500, result)
          end
        end
      end
      register_webhook(created_task)

      return created_task
    rescue Exception => e
      log('Create Task - ERROR', 500, {created_task: created_task&.inspect, error: e.message})
      return false
    end
  end

  def execute_request(url, is_post, post_data = nil)
    url = URI(url) rescue nil
    return false unless url.present?
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    if is_post
      request = Net::HTTP::Post.new(url)
      request.body = JSON.dump(post_data)
    else
      request = Net::HTTP::Get.new(url)
    end
    request["Asana-Enable"] = "new_rich_text"
    request["Accept"] = "application/json"
    request["content-type"] = "application/json"
    request["Authorization"] = "Bearer #{@integration.asana_personal_token}"

    response = http.request(request)
    log('Asana API response', response.code, JSON.parse(response.read_body))
    ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(@company)
    JSON.parse(response.read_body)
  end

  def post_attachment(attachment, task_id)
    File.open(attachment.original_filename, 'w') do |file|
      file.write(attachment.file.read)
    end
    response = "{}"
    url = URI.parse("https://app.asana.com/api/1.0/tasks/#{task_id}/attachments")
    type = MimeMagic.by_magic(File.open(attachment.original_filename)).type rescue "text/plain"
    File.open(attachment.original_filename) do |file|
      request = Net::HTTP::Post::Multipart.new(url.path, "file" => UploadIO.new(file, type, attachment.original_filename))
      req_options = {
        use_ssl: true
      }
      request["Accept"] = "application/json"
      request["Authorization"] = "Bearer #{@integration.asana_personal_token}"
      Net::HTTP.start(url.host, url.port, req_options) do |http|
        response = http.request(request)
      end
    end
    File.delete(attachment.original_filename)
    JSON.parse(response.read_body)
  end

  def register_webhook(task)
    url = URI::encode("https://app.asana.com/api/1.0/webhooks")
    if Rails.env != "development" && Rails.env != "test"
      webhook_url = "https://#{@company.domain}/api/v1/asana"
    else
      webhook_url = "https://#{@company.subdomain}.ngrok.io/api/v1/asana"
    end
    webhook_data = { data: {
      resource: task["data"]["gid"],
      target: webhook_url
    }}
    created_webhook = execute_request(url, true, webhook_data)
    if created_webhook["data"] && created_webhook["data"]["gid"]
      @tuc.update!(asana_webhook_gid: created_webhook["data"]["gid"])
    end
    created_webhook
  end

  def log(action, status, response, request = nil)
    LoggingService::IntegrationLogging.new.create(@company, 'Asana', action, request, response, status)
  end
end
