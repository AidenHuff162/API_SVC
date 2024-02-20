module Productivity
  module ServiceNow
    class Helper

      def fetch_integration(company)
        company.integration_instances.find_by(api_identifier: 'service_now')
      end

      def post_request(pay_load, data)
        url = "#{data[:domain]}/api/now/table/sc_task"
        RestClient.post(url, pay_load.to_json, generate_auth(data))
      end

      def put_request(pay_load, service_now_id, data)
        url = "#{data[:domain]}/api/now/table/sc_task/#{service_now_id}"
        RestClient.put(url, pay_load.to_json, generate_auth(data))
      end

      def delete_request(service_now_id, data)
        url = "#{data[:domain]}/api/now/table/sc_task/#{service_now_id}"
        RestClient.delete(url, generate_auth(data))
      end

      def get_completed_tasks(data)
        url = "#{data[:domain]}/api/now/table/sc_task?&state=#{build_update_state_data['state']}"
        RestClient.get(url, generate_auth(data))
      end

      def build_create_update_data(task_user_connection)
        {
          'short_description' => fetch_task_name(task_user_connection),
          'description' => fetch_task_description(task_user_connection),
          'due_date' => "#{task_user_connection.due_date.strftime('%Y-%m-%d')}"
        }
      end

      def build_update_state_data
        {
          'state' => 3
        }
      end

      def fetch_task_name(task_user_connection)
        task_name = fetch_text_from_html(ReplaceTokensService.new.replace_tokens(task_user_connection.task.name, task_user_connection.user, nil, nil, nil, true)) if task_user_connection.task.name.present?
        (task_name || '') + ' for ' + task_user_connection.user.full_name + ' [Sapling]'
      end

      def fetch_task_description(task_user_connection)
        task_description = ''
        if task_user_connection.task.description.present?
          task_description = ReverseMarkdown.convert(ReplaceTokensService.new.replace_tokens(task_user_connection.task.description, task_user_connection.user, nil, nil, nil, true, nil, false).gsub(/<img.*?>/, "").gsub(/<iframe.*?iframe>/, ""), unknown_tags: :bypass) rescue ""
          task_description = task_description.gsub(/(\\)([><])/, '\2')
        end
        task_description || ''
      end

      def task_user_connection_create_to_string(tuc)
        "{id: #{tuc.id}, user_id: #{tuc.user_id}, task_id: #{tuc.task_id}, state: #{tuc.state}, created_at: #{tuc.created_at}, updated_at: #{tuc.updated_at}, owner_id: #{tuc.owner_id}, due_date: #{tuc.due_date}, service_now_id: #{tuc.service_now_id} }"
      end

      def task_user_connection_update_to_string(task, task_user_connection)
        task_name = fetch_text_from_html(ReplaceTokensService.new.replace_tokens(task.name, task_user_connection.user, nil, nil, nil, true)) || '' if task.name.present?
        task_description = fetch_text_from_html(ReplaceTokensService.new.replace_tokens(task.description, task_user_connection.user, nil, nil, nil, true, nil, false)) || '' if task.description.present?
        "{name: #{task_name}, description: #{task_description}, id: #{task_user_connection.id}, user_id: #{task_user_connection.user_id}, task_id: #{task_user_connection.task_id}, state: #{task_user_connection.state}, created_at: #{task_user_connection.created_at}, updated_at: #{task_user_connection.updated_at}, owner_id: #{task_user_connection.owner_id}, due_date: #{task_user_connection.due_date}, service_now_id: #{task_user_connection.service_now_id} }"
      end

      def log(company, action, request, response, status)
        LoggingService::IntegrationLogging.new.create(company, 'ServiceNow', action, request, response, status)
      end

      def get_credentials(instance)
        {
          domain: instance.domain,
          username: instance.username,
          password: instance.password
        }
      end

      private

      def fetch_text_from_html(string)
        Nokogiri::HTML(string).xpath("//*[p]").first.content rescue ' '
      end

      def generate_auth(creds_data)
        { content_type: 'application/json', accept: 'application/json', Authorization: "Basic #{Base64.strict_encode64("#{creds_data[:username]}:#{creds_data[:password]}")}" }
      end
    end
  end
end