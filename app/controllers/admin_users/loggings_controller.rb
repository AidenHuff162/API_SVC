module AdminUsers
  class LoggingsController < ActionController::Base
    protect_from_forgery with: :exception, prepend: true, if: Proc.new { |c| c.request.format != 'application/json' }
    protect_from_forgery with: :null_session, prepend: true, if: Proc.new { |c| c.request.format == 'application/json' }

    before_action :authenticate_admin_user!
    before_action :set_company_names, only: [:index, :webhook, :sapling_api, :ct_logs, :pto_logs, :email_logs, :overall_logs, :papertrail_logs]
    before_action :set_integration_names, only: :index
    before_action :set_webhook_variables, only: :webhook
    before_action :set_papertrail_item_types, only: :papertrail_logs
    before_action :set_statuses, only: [:index, :sapling_api]
    before_action :set_papertrail_version, only: :papertrail_logs_show


    def index
      respond_to do |format|
        format.html
        format.json { render json: IntegrationDatatable.new(view_context, session) }
      end
    end

    def integration_logs_show
      @log = IntegrationLogging.where(partition_id: '2', timestamp: params[:id]).first
      @set_date = set_created_at 
      respond_to do |format|
        format.html
        format.json {
          if @log.present?
            render json: { data: @log, created_date: set_created_at  },  status: 200
          else 
            render json:{error: "Log not found!"}, status: :not_found
          end
        }
      end

    end

    def webhook
      respond_to do |format|
        format.html
        format.json { render json: WebhookDatatable.new(view_context, session) }
      end
    end

    def webhook_logs_show
      @log = WebhookLogging.where(partition_id: '2', timestamp: params[:id]).first
      @set_date = set_created_at 
      respond_to do |format|
        format.html
        format.json {
          if @log.present?
          render json: { data: @log, created_date: set_created_at  },  status: 200
          else 
            render json:{error: "Log not found!"},  status: :not_found
          end
          }
      end
    end

    def papertrail_logs_show
      respond_to do |format|
        format.html
        format.json {
          if @version.present?
            render json: {
              data: @version,
              company_name: company_name(@version),
              who: who_made_the_change(@version.whodunnit, true),
              when: format_date(@version.created_at),
              original_values: inspect_change_set(@version, true),
              new_values: inspect_change_set(@version, false)
            }, status: 200
          else
            render json: { error: 'Log not found!' },  status: :not_found
          end
        }
      end
    end

    def papertrail_logs
      @versions = filter_search(Version.order(id: :desc)).page(params[:page]).per(10)
    end

    def sapling_api
      respond_to do |format|
        format.html
        format.json { render json: SaplingApiDatatable.new(view_context, session) }
      end
    end

    def api_logs_show
      @log = SaplingApiLogging.where(partition_id: '2', timestamp: params[:id]).first
      @set_date = set_created_at
      respond_to do |format|
        format.html
        format.json {
          if @log.present?
            render json: { data: @log, created_date: set_created_at  },  status: 200
          else 
            render json:{error: "Log not found!"},  status: :not_found
          end
        }
      end
    end

    def ct_logs
      @url         = admin_ct_logs_path(format: :json)
      @name        = "Custom Table"
      respond_to do |format|
        format.html
        format.json { render json: GeneralDatatable.new(view_context, session, 'CustomTables') }
      end
    end

    def pto_logs

      @url = admin_pto_logs_path(format: :json)
      @name        = "PTO"
      respond_to do |format|
        format.html
        format.json { render json: GeneralDatatable.new(view_context, session, 'PTO') }
      end
    end

    def general_logs_show
      @log = GeneralLogging.where(partition_id: '2', timestamp: params[:id]).first
      @set_date = set_created_at
      respond_to do |format|
        format.html
        format.json {
          if @log.present?
            render json: { data: @log, created_date: set_created_at  },  status: 200
          else 
            render json:{error: "Log not found!"}, status: :not_found
          end    
        }
      end
    end

    def email_logs
      @action_name = admin_email_logs_path
      @url = admin_email_logs_path(format: :json)
      @name        = "Email"
      respond_to do |format|
        format.html
        format.json { render json: GeneralDatatable.new(view_context, session, 'Email') }
      end
    end

    def overall_logs
      @action_name = admin_overall_logs_path
      @url = admin_overall_logs_path(format: :json)
      @name        = "Overall"
      respond_to do |format|
        format.html
        format.json { render json: GeneralDatatable.new(view_context, session, 'Overall') }
      end
    end

    def export_loggings
      args = { filters: params[:params].to_json, loggings_type: params[:loggings_type], user_id: current_admin_user.id }
      Loggings::ExportLoggingsToAdminUserJob.perform_in(10.seconds, args)
    end

    private
    def set_created_at
      DateTime.strptime(@log.timestamp, '%Q').strftime('%d %b %Y  %H:%M:%S') rescue nil
    end

    def set_company_names
      @company_names = ['', 'None'] + Company.all_companies_alphabeticaly.pluck(:name)
    end

    def set_integration_names
      @integration_names = IntegrationLogging.integration_names
    end

    def set_statuses
      @statuses = IntegrationLogging.statuses
    end

    def set_webhook_variables
      @webhook_statuses = ['', 'None', 'succeed', 'failed']
      @webhook_names = WebhookLogging.webhook_names
    end

    def set_papertrail_version
      @version = Version.find(params[:id])
    end

    def set_papertrail_item_types
      @papertrail_item_types = ['', 'None'].concat(Version.order(:item_type).pluck(:item_type).uniq)
    end

    def filter_search(versions)
      if params[:company_name].present?
        versions = versions.where('company_name': params[:company_name])
      end
      if params[:item_type].present?
        versions = versions.where('item_type': params[:item_type])
      end
      if params[:user_id].present?
        versions = versions.where('whodunnit': params[:user_id])
      end
      if params[:date_from].present? && params[:date_to].present?
        versions = versions.where(created_at: params[:date_from].to_datetime.beginning_of_day..params[:date_to].to_datetime.end_of_day)
      elsif params[:date_from].present?
        versions = versions.where('created_at > ?', params[:date_from].to_datetime.beginning_of_day)
      elsif params[:date_to].present?
        versions = versions.where('created_at < ?', params[:date_to].to_datetime.end_of_day)
      end
      versions
    end

    def company_name(version)
      version.company_name || get_user_company_name(version)
    end

    def get_user_company_name(version)
      user = who_made_the_change(version.whodunnit, false) 
      if user && user.is_a?(User)
        user.company.name
      else
        'None'
      end
    end
  
    def format_date(date)
      date&.strftime('%d %b %Y  %H:%M:%S')
    end
  
    def who_made_the_change(whodunnit, format_user_name)
      if !whodunnit
        'Data Migration'
      elsif whodunnit.include?(':')
        'Console'
      else
        get_user(whodunnit, format_user_name)
      end
    end
  
    def get_user(id, format_user_name)
      user = User.find_by(id: id)
      if user && format_user_name
        user = '' + user.first_name + ' ' + user.last_name + ' (ID ' + user.id.to_s + ') ' + user.email 
      end
      user
    end
  
    def inspect_change_set (version, original_values)
      return nil if version.object_changes.blank?
  
      changes = PaperTrail.serializer.load(version.object_changes)
      inspected_values = {}
      changes.each { |k,v| inspected_values[k] = original_values ? changes[k][0] : changes[k][1]}
      inspected_values
    end
  end
end
