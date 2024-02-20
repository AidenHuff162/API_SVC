module Api
  module V1
    module Webhook
      class AsanaController < ApplicationController

        skip_before_action :authenticate_user!, raise: false
        skip_before_action :verify_current_user_in_current_company!, raise: false

        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 401
        end

        def create
          task_asana_ids = []
          params["events"].try(:each) do |event|
            if event["resource"] && event["resource"]["resource_subtype"] && event["resource"]["resource_subtype"] == "marked_complete"
              tuc = TaskUserConnection.find_by(asana_id: event["parent"]["gid"]) rescue nil
              if tuc.present? && tuc.task_id.present? && tuc.in_progress? && !tuc.task&.survey_id
                AsanaService::DeleteWebhook.new(tuc).perform
                tuc.state = "completed"
                tuc.completed_by_method = TaskUserConnection.completed_by_methods["asana"]
                tuc.asana_id = nil
                tuc.asana_webhook_gid = nil
                tuc.save
                tuc.activities.create!(agent_id: tuc.owner.id, description: "completed the task in asana")
                break
              end
            end
          end
          response.headers["X-Hook-Secret"] = request.headers["HTTP_X_HOOK_SECRET"]
          return render json: true, status: 200
        end

      end
    end
  end
end
