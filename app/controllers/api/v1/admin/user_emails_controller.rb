module Api
  module V1
    module Admin
      class UserEmailsController < BaseController
        load_and_authorize_resource :user
        load_and_authorize_resource :user_email, through: :user, shallow: true, except: [:emails_paginated, :restore, :delete_incomplete_email]
        before_action :set_history, only: [:update, :destroy]

        before_action only: [:emails_paginated] do
          if params[:offboarding_scheduled] || params[:offboarding_incomplete]
            ::PermissionService.new.checkAdminVisibility(current_user, 'emails', 'offboard_emails')
          elsif params[:admin_onbaord_access]
            ::PermissionService.new.checkAdminVisibility(current_user, 'dashboard')
          else
            ::PermissionService.new.checkAdminVisibility(current_user, 'emails')
          end
        end
        before_action only: [:show, :update, :destroy, :restore, :delete_incomplete_email] do
          if params[:offboarding_view]
            ::PermissionService.new.checkAdminCanViewAndEditVisibility(current_user, 'emails', 'offboard_emails')
          elsif params[:admin_onbaord_access]
            ::PermissionService.new.checkAdminVisibility(current_user, 'dashboard')
          else
            ::PermissionService.new.checkAdminCanViewAndEditVisibility(current_user, 'emails')
          end
        end

        def emails_paginated
          Time.zone = 'UTC'
          combined_emails_collection = CollectiveEmailsCollection.new(paginated_params)
          results = combined_emails_collection.results
          tab =  params[:incomplete] ? 'scheduled' : params[:tab]
          render json: {
            draw: params[:draw].to_i,
            recordsTotal: combined_emails_collection.count,
            recordsFiltered: combined_emails_collection.count,
            data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: UserEmailSerializer::Basic, tab: tab, company: current_company)
          }
        end

        def get_metrics
          Time.zone = 'UTC'
          current_date =  Date.today
          one_week_ago = Date.today - 1.week
          bi_week_ago = Date.today - 2.week
          date_range = one_week_ago.strftime("%b %d") + ' - ' + current_date.strftime("%b %d")
          send_emails_collection = CollectiveEmailsCollection.new({ current_company: current_company, current_user: current_user, tab: 'sent', date_filter: {start_date: one_week_ago, end_date: current_date}}).results
          schedule_emails_collection = CollectiveEmailsCollection.new({ current_company: current_company, current_user: current_user, tab: 'read', date_filter: {start_date: one_week_ago, end_date: current_date}}).results
          pre_send_emails_collection = CollectiveEmailsCollection.new({ current_company: current_company, current_user: current_user, tab: 'sent', date_filter: {start_date: bi_week_ago, end_date: one_week_ago}}).results
          pre_schedule_emails_collection = CollectiveEmailsCollection.new({ current_company: current_company, current_user: current_user, tab: 'read', date_filter: {start_date: bi_week_ago, end_date: one_week_ago}}).results
          render json: { sent_count: send_emails_collection&.length, read_count: schedule_emails_collection&.length, pre_sent_count: pre_send_emails_collection&.length, pre_read_count: pre_schedule_emails_collection&.length, metrics_date: date_range }, status: 200
        end

        def show
          respond_with @user_email, serializer: UserEmailSerializer::Full, company: current_company
        end

        def create_incomplete_email
          @user_email = UserEmail.new(user_email_params)
          @user_email.setup_recipients(params[:to]) if params[:to].present?
          set_invite_at
          @user_email.save!
          # @user_email.assign_template_attachments(params[:template_attachments]) if params[:template_attachments].present?
          if @user_email.errors
            render json: {errors: @user_email.errors.messages}, status: 200
          else
            render json: @user_email, status: 200
          end
        end

        def create_default_onboarding_emails
          @user.schedule_default_onboarding_emails current_user.id if @user.smart_assignment
          render body: Sapling::Application::EMPTY_BODY, status: 200
        end

        def create_default_offboarding_emails
          @user.assign_default_offboarding_emails(params.to_h, current_user.id) if @user.smart_assignment
          render body: Sapling::Application::EMPTY_BODY, status: 200
        end

        def delete_incomplete_email
          @user.destroy_all_incomplete_emails
          render body: Sapling::Application::EMPTY_BODY, status: 200
        end

        def create
          if params[:test]
            test
            return
          end
        end

        def schedue_email
          @user_email = UserEmail.new(user_email_params)
          @user_email.setup_recipients(params[:to]) if params[:to].present?
          if params[:schedule_options].present?
            set_invite_at
            @user_email.save
            @user_email.assign_template_attachments(params[:template_attachments])
            @user_email.send_user_email(params[:is_daylight_save])
          end
          if @user_email.errors.present?
            render json: {errors: @user_email.errors.messages}, status: 200
          else
            render json: @user_email, status: 200
          end
        end

        def update
          @user_email.update(user_email_params)
          @user_email.setup_recipients(params[:to]) if params[:to].present?
          #Only update from inbox page
          @user_email.delete_scheduled unless @user_email.email_status == UserEmail::statuses[:incomplete]
          set_invite_at
          @user_email.save
          @user_email.send_user_email(params[:is_daylight_save]) unless @user_email.email_status == UserEmail::statuses[:incomplete]
          History.update_scheduled_email(@history, params[:invite_at]) if @user_email.email_status != UserEmail::statuses[:incomplete] && @history.present? && params[:invite_at].present?
          respond_with @user_email, serializer: UserEmailSerializer::Basic, tab: 'scheduled', company: current_company
        end

        def test
          @user_email.setup_recipients(params[:to]) if params[:to].present?
          interaction = Interactions::UserEmails::ScheduleCustomEmail.new(@user_email, false)
          interaction.perform_test(current_user)
          render body: Sapling::Application::EMPTY_BODY, status: 200
        end

        def destroy
          params[:really_destroy] ? @user_email.really_destroy! : @user_email.destroy
          render :json => {status: 200, history: @history.to_json}
        end

        def restore
          # TODO check perission
          user_email = UserEmail.with_deleted.find_by(id: params[:id])
          user_email.update_column(:deleted_at, nil)
          respond_with user_email, serializer: UserEmailSerializer::Basic, tab: 'scheduled', company: current_company
        end

        def contact_us
          if params[:name].present? && params[:email].present? && params[:message].present?
            Company::ContactUs.perform_async(params[:name], params[:email], params[:message], current_user.id, current_company.id, params[:modal_name], params[:origin])

            render json: {status: 200}
          else
            render json: { error: 'Input data is missing', status: 422}
          end
        end


        private

        def paginated_params
          page = (params[:start].to_i / params[:length].to_i) + 1
          params.merge(
            current_company: current_company,
            current_user: current_user,
            page: page,
            per_page: params[:length].to_i,
            order_column: params[:order_column],
            order_in: params[:order_in]
          )
        end

        def user_email_params
          params.permit(:to, :subject, :cc, :bcc, :description, :invite_at, :email_status, :email_type, :sent_at, :template_name, :from, :user_id, :scheduled_from,
           schedule_options: [:due, :time, :date, :duration, :send_email, :relative_key, :duration_type, :time_zone, :set_onboard_cta, :email_to], template_attachments: [:id, :download_url, :original_filename]).merge(attachment_ids: attachment_ids, editor_id: current_user.id)
        end

        def attachment_ids
          attachment_ids = (params[:attachments] || []).map { |attachment| attachment[:id] }
          attachment_ids
        end

        def authorize_attachments
          UploadedFile::Attachment.where(id: attachment_ids).find_each do |attachment|
            authorize! :manage, attachment
          end
        end

        def set_invite_at
          if params[:schedule_options].present? && params[:schedule_options]["send_email"] == 1 #custome scheduled date
            date = Time.zone.parse(params[:schedule_options]["date"].to_s)
            date = date + Time.zone.parse(params[:schedule_options]["time"]).seconds_since_midnight.seconds if params[:schedule_options]["time"].present?
            @user_email.invite_at = date
          elsif params[:schedule_options].present? && params[:schedule_options]["send_email"] == 2 #relative to key date
            # There are four keys here start date, Termination Date and anniversary date, birthday
            date = get_key_date
            if params[:schedule_options]["time"].present? && date.present?
              date = date + Time.zone.parse(params[:schedule_options]["time"]).seconds_since_midnight.seconds
            end
            @user_email.invite_at = date
          elsif params[:schedule_options].present? && params[:schedule_options]["send_email"] == 0
            @user_email.invite_at = nil
          end
        end

        def get_key_date
          user = @user_email.user
          if  ['start date', 'last day worked', 'date of termination'].include?(params[:schedule_options]["relative_key"])
            if params[:schedule_options]["relative_key"] == 'start date'
              date = user.start_date
            elsif params[:schedule_options]["relative_key"] == 'last day worked'
              date = params[:last_day_worked].try(:to_date)
              @user_email.schedule_options['last_day_worked'] = date
            elsif params[:schedule_options]["relative_key"] == 'date of termination'
              date = params[:termination_date].try(:to_date)
              @user_email.schedule_options['termination_date'] = date
            end

            if params[:schedule_options]["due"] == 'on'
              return date
            elsif params[:schedule_options]["due"] == 'before'
              # date - 3.days or 3.weeks etc
              duration_type_method = params[:schedule_options]["duration_type"] == 'days' ? 'days' : 'weeks'
              return (date - params[:schedule_options]["duration"].to_i.public_send(duration_type_method))
            elsif params[:schedule_options]["due"] == 'after'
              duration_type_method = params[:schedule_options]["duration_type"] == 'days' ? 'days' : 'weeks'
              return (date + params[:schedule_options]["duration"].to_i.public_send(duration_type_method))
            end
          elsif params[:schedule_options]["relative_key"] == 'birthday'
            return user.get_date_wrt_birthday(params[:schedule_options]["due"], params[:schedule_options]["duration"].to_s, params[:schedule_options]["duration_type"])
          elsif params[:schedule_options]["relative_key"] == 'anniversary'
            return user.get_date_wrt_anniversary(params[:schedule_options]["due"], params[:schedule_options]["duration"].to_s, params[:schedule_options]["duration_type"])
          end
        end

        def set_history
          @history = @user_email.user.histories.where(user_email_id: @user_email.id).take rescue nil
        end
      end
    end
  end
end
