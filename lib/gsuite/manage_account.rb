require 'google/apis/admin_directory_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'i18n'
require 'ldclient-rb'

module Gsuite
  class ManageAccount

    if ENV['FETCH_ENVS_FROM_REMOTE_URL'] == 'true'
      CLIENT_ID = Google::Auth::ClientId.from_hash(JSON.parse(ENV['GOOGLE_AUTH_CONFIG']))
    else
      if Rails.env.development? || Rails.env.test?
        CLIENT_SECRETS_PATH = ('client_secret.json')
      else
        CLIENT_SECRETS_PATH = File.join(Dir.home, 'www/sapling/shared/config', 'client_secret.json')
      end
      CLIENT_ID = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
    end
    CREDENTIALS_PATH = File.join(Dir.home, '.credentials', "admin-directory_v1-ruby-sapling.yaml")
    SCOPE = [Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_USER]
    OUGROUPS = [Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_ORGUNIT_READONLY,Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_GROUP_MEMBER,Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_GROUP_READONLY]

    def get_service_object
      # Initialize the API
      service = Google::Apis::AdminDirectoryV1::DirectoryService.new
      service
    end
   
    def auth_client company
      begin
        FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))
        token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
        scope  = company.google_groups_feature_flag ? (SCOPE + OUGROUPS) : SCOPE
        authorizer = Google::Auth::UserAuthorizer.new(
          CLIENT_ID, scope, token_store)
        credentials = authorizer.get_credentials_from_relation(company, company.id)
        logger.info "!!!!!!!!!!!!!!!!!!!!!!!TESTLOGS123!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        logger.info credentials
      rescue Exception => e
        log(company, 'Auth', 'N/A',  {error: "GSUITE AUTH ERROR"}, 500)
      end
      credentials
    end

    def delete_gsuite_account user
      company = user.company

      if company.get_gsuite_account_info.present?
        service = get_service_object
        service.authorization = auth_client(company)
        begin
          account = service.get_user(user.email)
          account.update!(suspended: true)
          result = service.patch_user(user.email, account)
          user.update_columns(gsuite_account_exists: false, gsuite_account_deprovisioned: true)
          log(company, 'Offboarding', account.inspect, {success: result.inspect}, 200)
        rescue Exception => e
          puts "!!!!!GSUITE DELETION ERROR!!!!!"
          puts e
          log(company, 'Offboarding', account.inspect,  {error: "#{e.message} for user with email #{user.email}"}, 500)
        end
      end
    end

    def reactivate_gsuite_account user
      company = user.company

      if company.get_gsuite_account_info.present?
        service = get_service_object
        service.authorization = auth_client(company)
        begin
          account = service.get_user(user.email)
          account.update!(suspended: false)
          result = service.patch_user(user.email, account)
          user.update_column(:gsuite_account_exists, true)
          log(company, 'Rehiring', account.inspect, {success: result.inspect}, 200)
        rescue Exception => e
          puts "!!!!!GSUITE Rehiring ERROR!!!!!"
          puts e
          log(company, 'Rehiring', account.inspect,  {error: "#{e.message} for user with email #{user.email}"}, 500)
        end
      end
    end

    def update_gsuite_account(user_id, update_ou)
      user = User.find(user_id)
      return unless user.present?
        
      company = user.company
      gsuite_account_info = company.get_gsuite_account_info
      return unless gsuite_account_info.present?

      email = get_user_updated_email(user, gsuite_account_info.gsuite_account_url)

      if email.present?
        service = get_service_object
        service.authorization = auth_client(company)
        user_gsuite_key = user.gsuite_id.present? ? user.gsuite_id : user.email
        begin
          account = service.get_user(user_gsuite_key)
          
          if update_ou && company.google_groups_feature_flag.present?
            ou_path = user.get_custom_field_value_text('Google Organization Unit', false, nil, nil, false, nil, false, false, false, false, nil, true)
            account.update!(primary_email: email, org_unit_path: ou_path || '/')
          else
            account.update!(primary_email: email, name: Google::Apis::AdminDirectoryV1::UserName.new(given_name: (user.preferred_name || user.first_name), family_name: user.last_name))
          end
          
          result = service.patch_user(user_gsuite_key, account)

          user_data = { email: email }
          user_data[:uid] = email if user.uid == user.email
          user.update(user_data)

          log(company, 'Update GSuite Email', account.inspect, {success: result.inspect, gsuite_key: user_gsuite_key}, 200)
        rescue Exception => e
          log(company, 'Update GSuite Email', account.inspect,  {error: "#{e.message} for user with email #{email}", gsuite_key: user_gsuite_key, user_id: user.id}, 500)
        end
      end
    end

    def create_gsuite_account user, gsuite_info_object, company
       # Initialize the API
      response = {response_error: ""}
      service = get_service_object
      # service.authorization = authorize(gsuite_info_object)
      service.authorization = auth_client(company)
      user_object = Google::Apis::AdminDirectoryV1::User.new
      user_object.primary_email = user.email
      user_object.emails = [{address: user.personal_email, type: "custom", customType: ""}] if company.link_gsuite_personal_email.present? && user.personal_email.present?
      user_object.name = Google::Apis::AdminDirectoryV1::UserName.new
      user_object.name.given_name = user.first_name
      user_object.name.family_name = user.last_name
      user_object.organizations = [{name: user.company.name, title: user.title, type: "work", department: user.team.present? ? user.team.name : "", location: user.location.present? ? user.location.name : "", domain: user.company.domain}]
      user_object.organizations[0].merge!(primary: true) if company.subdomain == 'warbyparker' || Rails.env.staging?
      user_object.addresses = [{ formatted: user.location.name , type: "work"}] if user.location.present?
      user_object.relations = [{value: user.manager.email, type: "manager"}] if user.manager.present? and managers_email_is_valid(user, gsuite_info_object.gsuite_account_url)
      user_object.password = ([*('a'..'z'),*('0'..'9')]-%w(0 1 I O)).sample(8).join

      user_object.change_password_at_next_login = true
      user_object.suspended = false
      if company.google_groups_feature_flag.present?
        ou_path = user.get_custom_field_value_text('Google Organization Unit', false, nil, nil, false, nil, false, false, false, false, nil, true)
        user_object.org_unit_path  = ou_path || '/'
      end
      begin
        puts "!!!!!!USER GSUITE CREATION!!!!!!"
        result = service.insert_user(user_object)
        gsuite_id = result.id rescue nil
        insert_group_member(company, user, result, service) if company.google_groups_feature_flag.present? && result.present? && result.id.present? rescue nil
        user.update(gsuite_initial_password: user_object.password, gsuite_account_exists: true, gsuite_id: gsuite_id)        
        log(company, 'Onboarding', user_object.inspect, {success: result.inspect}, 200)
        
        description = "#{user.first_name} #{user.last_name}'s G-Suite Account has been provisioned."
        if company.link_gsuite_personal_email.present?
          user.send_provising_credentials
          description = description + " They'll be notified at 8am on their start date via their personal email address."
        end

        history = History.new(company_id: company.id, user_id: user.id, description: description)
        history.save!
        history.history_users.create!(user_id: user.id)
      rescue Exception => e
        puts "!!!!!!ERROR USER GSUITE CREATION!!!!!!"
        puts  e.message
        response = {response_error: e.message.split(':').last}
        log(company, 'Onboarding', user_object.inspect, {error: e.message}, 500)
      end

      response
    end

    def insert_group_member(company, user, account, service)
      begin
        member_object = Google::Apis::AdminDirectoryV1::Member.new
        member_object.email = account.primary_email
        member_object.id = account.id
        keys = user.get_custom_field_value_text('Google Groups', false, nil, nil, false, nil, false, false, false, false, nil, true)
        if keys.present?
          keys.each do |key|        
            result = service.insert_member(key, member_object) rescue nil
            log(company, 'insert-group-member', member_object.inspect, {success: result.inspect}, 200) if result.present?
          end
        end
      rescue Exception => e
        puts "!!!!!Groups Member Insert Failed!!!!!"
        puts e
        log(company, 'insert-group-member', member_object.inspect,  {error: "#{e.message} for user id #{user.id}"}, 500)
      end
    end

    def get_gsuite_groups(company)
      service = get_service_object
      service.authorization = auth_client(company)
      begin
        res = service.list_groups(customer: 'my_customer')
        groups = res.groups
        while (res.next_page_token)
          res = service.list_groups(customer: 'my_customer', page_token: res.next_page_token)
          groups = groups + res.groups
        end
        position = CustomField.get_valid_custom_field_position(company, CustomField.sections[:personal_info])

        group_field = CustomField.find_or_initialize_by(name: "Google Groups", company_id: company.id, field_type: 12)
        
        group_field.attributes = { locks:{all_locks: true}, section: 0, position: position, collect_from: CustomField.collect_froms[:admin] } if group_field.id.blank?

        group_field.save!
        if groups.present?
          get_and_assign_gsuite_option(group_field, groups)
          log(company, 'groups-mapping', groups.inspect, {success: groups.inspect}, 200)
        end
      rescue Exception => e
        puts "!!!!!Groups Mapping Failed!!!!!"
        puts e
        log(company, 'groups-mapping', groups.inspect,  {error: "#{e.message} for company id #{company.id}"}, 500)
      end
    end

    def get_gsuite_ou(company)
      service = get_service_object
      service.authorization = auth_client(company)
      begin
        ous = service.list_org_units('my_customer', type: 'all').organization_units
        position = CustomField.get_valid_custom_field_position(company, CustomField.sections[:personal_info])

        ou_field = CustomField.find_or_initialize_by(name: 'Google Organization Unit', company_id: company.id, field_type: 4)

        ou_field.attributes = { locks: {all_locks: true}, section: 0, position: position, collect_from: CustomField.collect_froms[:admin] } if ou_field.id.blank?
        ou_field.save!
        
        if ous.present?
          ous.uniq! {|e| e.name }
          get_and_assign_gsuite_option(ou_field, ous, true)
          log(company, 'organizational-unit-mapping', ous.inspect, {success: ous.inspect}, 200)
        end
      rescue Exception => e
        puts "!!!!!Organizational Unit Mapping Failed!!!!!"
        puts e
        log(company, 'organizational-unit-mapping', ous.inspect,  {error: "#{e.message} for company id #{company.id}"}, 500)
      end
    end 
    def managers_email_is_valid user_object, company_gsuite_url
      if user_object.manager.present? and user_object.manager.email.present?
        email = user_object.manager.email
        email.split("@").last == company_gsuite_url ? true : false
      else
        false
      end
    end

    def get_user_updated_email(user, company_gsuite_url)
      return unless company_gsuite_url.present?
      initial_part = I18n.transliterate((user.preferred_name || user.first_name)).downcase.strip.split(' ').map!{|ip| ip.tr('^a-z', '')}.compact.join('.')
      return unless initial_part.present?
      last_part = I18n.transliterate(user.last_name).downcase.strip.tr('^a-z', '')
      if (initial_part.tr('^a-z', '').length + last_part.length + 1) > 20
        return "#{initial_part.split('.').map!{|ip| ip[0]}.join}.#{last_part}@#{company_gsuite_url}"
      else
        return "#{initial_part.tr('^a-z', '')}.#{last_part}@#{company_gsuite_url}"
      end
    end

    def log(company, action, request, response, status)
      LoggingService::IntegrationLogging.new.create(company, 'GSuite', action, request, response, status)
    end

    def get_and_assign_gsuite_option(option_field, options, is_gsuite_option = false)
      updated_option_ids = []
      cf_option = -1

      options.each do |option|
        gsuite_mapping_key = is_gsuite_option ? option.org_unit_path : option.id

        custom_field_option = CustomFieldOption.find_by(custom_field_id: option_field.id, option: option.name) || CustomFieldOption.find_by(custom_field_id: option_field.id, gsuite_mapping_key: gsuite_mapping_key)
        #to handle case if name is same but id is updated in gsuite
        custom_field_option = CustomFieldOption.new(custom_field_id: option_field.id) unless custom_field_option
        custom_field_option.assign_attributes(gsuite_mapping_key: gsuite_mapping_key, option: option.name, position: cf_option+=1, active: true)
        custom_field_option.save
        updated_option_ids.push(custom_field_option.id)
      end

      option_field.custom_field_options.where.not('id IN (?)', updated_option_ids).where('gsuite_mapping_key IS NOT NULL').update_all(active: false)
    end
  end
end
