namespace :sapling do

  ## Task for Gsuite user credential migration from yml to db for given company id
  desc "[YML 2 DB] Store company gsuite credential into google_credential table"
  task :store_company_gsuite_credential,[:company_id] =>:environment do |t, args|
    credentials = YAML.load_file(File.join(Dir.home, '.credentials', "admin-directory_v1-ruby-sapling.yaml"))
    company = Company.find_by(id:args.company_id)
    if company && credentials[company.id]
      puts " [YML to DB] Storing company gsuite credential for #{company.id}"
      company.read_and_store_credentials_in_db(credentials[company.id])
    end
  end

  desc "Generate uniq UUID for each company"
  task generate_company_uuid: :environment do
    #TODO delete it after execution
    Company.find_each do |company|
      company.create_uuid
      puts "Create UUID for #{company.subdomain}"
    end
    puts "Task completed successfully"
  end

  ## Task for Gsheet user credentials migration from yml to db for given company id
  desc "[YML 2 DB] Store company users gsheet credential into google_credential table"
  task :store_company_users_gsheet_credential, [:company_id]=> :environment do |t, args|
    credentials = YAML.load_file(File.join(Dir.home, '.credentials', "gsheet_v4-ruby-sapling.yaml"))
    company = Company.find_by(id: args.company_id)
    company_users = company.users
    if company_users.present?
      company_users.each do |user|
        puts "USER [#{user.id}] :: GOOGLE_CREDENTIAL_ID[#{user.get_google_auth_credential_id}]"
        if credentials[user.get_google_auth_credential_id]
          puts " [YML to DB] Storing #{user.get_google_auth_credential_id} gsheet credential"
          user.read_and_store_credentials_in_db(credentials[user.get_google_auth_credential_id])
        end
      end
    end
  end

  desc "[DB 2 YML] company gsuite credential from goolge_credential table to yml"
  task :read_company_gsuite_credential,[:company_id] =>:environment do |t, args|
    # credentials = YAML.load_file(File.join(Dir.home, '.credentials', "admin-directory_v1-ruby-sapling.yaml"))
    company = Company.find_by(id:args.company_id)
    if company && company.google_credential

      ######### file name in which credential will store #####################
      file_name = "#{company.id}_admin-directory_v1-ruby-sapling.yaml" #diff file with company id as prefix to avoid updating existing file
      #file_name = "admin-directory_v1-ruby-sapling.yaml"  ## exising file directly
      #########################################################################
      if company.google_credential.credentials.class == Hash
         credentials = company.google_credential.credentials
      else
         credentials = JSON.parse(company.google_credential.credentials)
      end
      json = {
        client_id:              credentials['client_id'],
        access_token:           credentials['access_token'],
        refresh_token:          credentials['refresh_token'],
        scope:                  credentials['scope'],
        expiration_time_millis: credentials['expiration_time_millis']
      }

      puts " [DB to YML] Append into yml company gsuite credential for #{company.id} under file #{file_name}"
      company_credential = {}
      company_credential[company.id] = json
      File.open(File.join(Dir.home, 'credentials', file_name), 'a') { |file| file.write(company_credential.to_yaml) }
    end
  end

  desc "[DB 2 YML]  company users gsheet credential into google_credential table"
  task :read_company_users_gsheet_credential, [:company_id]=> :environment do |t, args|
    # credentials = YAML.load_file(File.join(Dir.home, '.credentials', "gsheet_v4-ruby-sapling.yaml"))
    company = Company.find_by(id: args.company_id)
    company_users = company.users
    if company_users.present?
      company_users.each do |user|
        if user.google_credential

          ######### file name in which credential will store #####################
          file_name = "#{user.get_google_auth_credential_id}_gsheet_v4-ruby-sapling.yaml" #diff file with user name as prefix
          #file_name = "gsheet_v4-ruby-sapling.yaml"  ## exising file directly
          #########################################################################
          if user.google_credential.credentials.class == Hash
            credentials = user.google_credential.credentials
          else
            credentials = JSON.parse(user.google_credential.credentials)
          end
          json = {
            client_id:              credentials['client_id'],
            access_token:           credentials['access_token'],
            refresh_token:          credentials['refresh_token'],
            scope:                  credentials['scope'],
            expiration_time_millis: credentials['expiration_time_millis']
          }

          puts " [DB to YML] #{user.get_google_auth_credential_id} gsheet credential under file #{file_name}"
          user_credential = {}
          user_credential[user.get_google_auth_credential_id] = json
          File.open(File.join(Dir.home, '.credentials', file_name), 'a') { |file| file.write(user_credential.to_yaml) }

        end
      end
    end
  end

  desc "Delete company and associated data"
  task :remove_company_data, [:subdomain] => :environment do |t, args|
    company = Company.find_by(subdomain: args.subdomain)
  	if company
      remove_company_data_and_associations(company)
      puts "Deleted #{args.subdomain} data "
    else
      puts "Failed to remove company #{args.subdomain}"
  	end
  end


  desc "Reset Org chart for company"
  task :update_org_chart, [:subdomain] => :environment do |t, args|
  	company = Company.find_by(subdomain: args.subdomain)
  	if company
			company.run_create_organization_chart_job
			puts "Updated #{company.subdomain} org_chart"
  	else
			puts "Failed to update org_chart of #{args.subdomain}"
  	end
  end

  desc "Rest employee role for those managers who do not manage any user."
  task reset_user_role_for_manager: :environment do
    effected_users = []
    User.joins(:user_role).where(user_roles: {role_type: UserRole.role_types[:manager]}).find_each do |manager|
      if manager.managed_users.length == 0
        employee_role = manager.company.user_roles.where(role_type: UserRole.role_types[:employee], is_default: true).first
        if employee_role.present?
          data = {user_id: manager.id, previous_role_id: manager.user_role_id, new_role_id: employee_role.id}
          effected_users.push(data)
          manager.update_column(:user_role_id, employee_role.id)
          manager.flush_cached_role_name
        end
      end
    end
    puts "Task sucessfully executed and #{effected_users.length} users effected here is the details"
    puts effected_users.inspect
  end

  desc "Reset Org chart for all companies"
  task regenerate_organization_chart: :environment do
    Company.where(enabled_org_chart: true).find_each do |company|
      company.run_create_organization_chart_job
    end
  end

  desc "Set email type for welcome email"
  task update_packet_connections: :environment do
    @impected_companies_ids = []
    types = ['Onboarding','Offboarding','Relocation','Promotion', 'Other']
    Company.find_each do |company|
      @moved_docs = []
      @moved_upload_requests = []
      types.each do |type|
        paperwork_packets = company.paperwork_packets.where("meta->>'type' = ?", type)
        paperwork_packets.each do |packet|
          packet.paperwork_packet_connections.each do |connection|
            if connection.connectable_type == 'DocumentUploadRequest' && connection.connectable
              if connection.connectable.meta["type"] != type
                dur = connection.connectable
                unless @moved_upload_requests.include?(dur.id)
                  @moved_upload_requests.push(dur.id)
                  meta = dur.meta
                  meta["type"] = type
                  dur.update_column(:meta, meta)
                  @impected_companies_ids.push(packet.company_id)
                else
                  connection.destroy
                end
              end
            elsif connection.connectable_type == 'PaperworkTemplate' && connection.connectable
              document = connection.connectable.document
              if document && document.meta["type"] != type
                unless @moved_docs.include?(document.id)
                  meta = document.meta
                  @moved_docs.push(document.id)
                  meta["type"] = type
                  document.update_column(:meta, meta)
                  @impected_companies_ids.push(packet.company_id)
                else
                  connection.destroy
                end
              elsif document == nil
                connection.destroy
              end
            end
          end
        end
      end
      puts company.name + "completed"
    end
    puts "Total impected companies ids =#{@impected_companies_ids.uniq.to_s}"
  end

  desc "Assign user to the invit"
  task assign_user_relation_with_invite: :environment do
    Invite.where.not(user_email_id: nil).includes(:user_email).find_each do |invit|
      user_email = invit.user_email
      invit.update_column(:user_id, user_email.user_id) if user_email
    end
    puts "Task successfully completed."
  end

  desc "Migrate Invitation Email table data to UserEmails table"
  task remove_template_attachments: :environment do
    UserEmail.where.not(email_status: UserEmail::statuses[:incomplete]).update_all(template_attachments: [])
    puts "--------------- Rake task successfully completed -----------------\n"
  end

  desc "Assign relation to user email with invite"
  task assign_user_email_id_to_invite: :environment do
    Invite.where.not(user_id: nil).where(user_email_id: nil).find_each do |invit|
      email = UserEmail.where(email_type: 1).where(user_id: invit.user_id).last
      invit.update_column(:user_email_id, email.id) if email.present?
    end
  end

  desc "destroye Default onboarding invitation template under notification tab"
  task destroy_default_onboarding_invitation_template: :environment do
    Company.find_each do |company|
      invite_template = company.email_templates.find_by_email_type('onboarding_invitation')
      invite_template.destroy if invite_template
    end
    puts "Task successfully completed"
  end

  desc "Set to email address for all emails those already have been sent"
  task set_to_email_address_for_user_emails: :environment do
    UserEmail.where(email_status: 3).find_each do |user_email|
      emails = []
      user = user_email.user
      next unless user
      if user_email.scheduled_from == 'onboarding' || (user_email.email_type == 'invitation' && user_email.scheduled_from == nil)
        if !user.onboard_email
          user.email.present? ? emails.push(user.email) : emails.push(user.personal_email)
        elsif user.onboard_email == 'personal'
          emails.push user.personal_email
        elsif user.onboard_email == 'company'
          emails.push user.email
        elsif user.onboard_email == 'both'
          emails.push(user.email) if user.email
          emails.push user.personal_email
        end
      else
        user.email ? emails.push(user.email) : emails.push(user.personal_email)
      end
      user_email.update_column(:to, emails)
    end
    puts "Task successfully completed"
  end


  def remove_company_data_and_associations(company)
    puts "START:: Company deletion----------"
    start_time = Time.now
    time = Benchmark.measure do
        puts "Removing Company users........."
        company.integrations.find_each  do |integration|
          integration.really_destroy!
        end
        puts  "-------Integrations destroyed---------"
        ## Company users and associated data
        users = company.users
        users.each do |user|
          puts "Removing user #{user.full_name}------------"
          PtoBalanceAuditLog.where(user_id: user.id).delete_all
          Team.where(owner_id: user.id).delete_all
          Location.where(owner_id: user.id).delete_all
          PaperworkRequest.where(user_id: user.id).delete_all
          PaperworkRequest.where(co_signer_id: user.id).delete_all
          UserDocumentConnection.where(user_id: user.id).delete_all
          UserDocumentConnection.where(created_by_id: user.id).delete_all
          CustomFieldValue.where(user_id: user.id).delete_all

          pto_requests = PtoRequest.where(user_id: user.id)
          pto_requests.each do |pto_request|
            puts "Removing PTO Request..."
            Activity.where(partner_pto_request_id: pto_request.id).destroy_all
            CalendarEvent.where(eventable_id: pto_request.id,eventable_type: "PtoRequest").delete_all
          end

          Invite.where(user_id: user.id).delete_all

          UserEmail.where(user_id: user.id).delete_all
          TerminationEmail.where(user_id: user.id).delete_all
          AnonymizedDatum.where(user_id: user.id).delete_all
          DeletedUserEmail.where(user_id: user.id).delete_all

          tasks = Task.where(owner_id: user.id)
          tasks.each do |task|
            TaskUserConnection.where(task_id: task.id).delete_all
            Tasks.where(id:task.id).delete_all
          end

          upload_files = UploadedFile.where(entity_id:user.id)
          upload_files.each do |up_file|
            puts up_file.inspect
          end

          DocumentUploadRequest.where(user_id: user.id).delete_all
          History.where(user_id: user.id).delete_all
          HistoryUser.where(user_id: user.id).delete_all

          paperwork_templates = PaperworkTemplate.where(representative_id: user.id)
          paperwork_templates.each do |pt|
            puts pt.inspect
            PaperworkPacketConnection.where(connectable_id: pt.id,connectable_type:"PaperworkTemplate").delete_all
          end

          paperwork_packets =  PaperworkPacket.where(user_id: user.id)
          paperwork_packets.each do |paperwork_packet|
            PaperworkPacketConnection.where(connectable_id: paperwork_packet.id,connectable_type:"PaperworkPacket").delete_all
          end

          reports = Report.where(user_id: user.id)
          reports.each do |r|
            CustomFieldReport.where(report_id: r.id).delete_all
          end

          CalendarFeed.where(user_id: user.id).delete_all
          FieldHistory.where(field_changer_id: user.id).delete_all
          CustomFieldOption.where(owner_id: user.id).delete_all
          PendingHire.where(user_id: user.id).delete_all
          Comment.where(commenter_id: user.id).delete_all
          Activity.where(agent_id: user.id).destroy_all
          PersonalDocument.where(user_id: user.id).delete_all
          CustomTableUserSnapshot.where(edited_by_id: user.id).delete_all
          CustomTableUserSnapshot.where(requester_id: user.id).delete_all
          CustomEmailAlert.where(edited_by_id: user.id).delete_all
          CustomTableUserSnapshot.where(user_id: user.id).delete_all
          ApiKey.where(edited_by_id: user.id).delete_all
          RequestInformation.where(requester_id: user.id).delete_all
          RequestInformation.where(requested_to_id: user.id).delete_all
          WorkspaceMember.where(member_id: user.id).delete_all

          pto_policies = PtoPolicy.where(created_by_id: user.id)
          pto_policies.each do |pto|
            AssignedPtoPolicy.where(pto_policy_id: pto.id).delete_all
            UnassignedPtoPolicy.where(pto_policy_id: pto.id).delete_all
            PtoRequest.where(pto_policy_id: pto.id).delete_all
            PolicyTenureship.where(pto_policy_id: pto.id).delete_all
            ApprovalChain.where(approvable_id: pto.id,approavble_type: "PtoPolicy").delete_all
          end
          GoogleCredential.where(credentialable_id: user.id,credentialable_type: "User").delete_all
          GoogleCredential.where(credentialable_id: user.id,credentialable_type: "Company").delete_all

          FieldHistory.where(field_auditable_id: user.id,field_auditable_type: "User").delete_all
          CalendarEvent.where(eventable_id: user.id,eventable_type: "User").delete_all
          user.really_destroy!
        end


        company.custom_tables.with_deleted.find_each do | ct|
         ct.really_destroy!
        end
        puts  "-------------Custom Tables Destroyed------------------"
        company.locations.with_deleted.find_each do |location|
         location.really_destroy!
        end
        puts  "--------------Locations destroyed--------------------"
        company.pending_hires.destroy_all
        puts  "------------Pending Hires Destroyed-------"
        company.workstreams.with_deleted.find_each do |workstream|
          workstream.really_destroy!
        end
        puts  "------All workstreams destroye-------"
        company.workspaces.with_deleted.destroy_all
        puts  "----All workspaces destroyed---------"
        company.api_keys.destroy_all
        puts "--------------API keys destroyed--------------------"
        CustomField.where(company_id: company.id).destroy_all
      end
      company.really_destroy!
      time_taken = (Time.now - start_time) * 1000
      puts "END:: Company deletion---------"
      puts "Time elapsed #{time_taken} milliseconds"
      puts "Benchmark CPU #{time}"
      #has_one :organization_root_company, class_name: :Company, foreign_key: "organization_root_id", dependent: :nullify
  end

end
