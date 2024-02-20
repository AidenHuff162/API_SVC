module Interactions
  module HistoryLog
    class CustomFieldHistoryLog
      def self.log(tempUser,params,current_user)
        current_company = current_user.company
        
        if params["first_name"] && tempUser.first_name != params["first_name"]
          if current_user.id == tempUser.id
            history_description = I18n.t("history_notifications.user.updated.personal_information", first_name: current_user.first_name, last_name: current_user.last_name ,field_name: "First Name")
          else
            history_description = I18n.t("history_notifications.custom_field.updated", user_first_name: current_user.first_name, user_last_name: current_user.last_name, field_name: "First Name", employee_first_name: tempUser.first_name, employee_last_name: tempUser.last_name)
          end
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: history_description,
            attached_users: [tempUser.try(:id)]
          })
        end
        if params["last_name"] && tempUser.last_name != params["last_name"]
          if current_user.id == tempUser.id
            history_description = I18n.t("history_notifications.user.updated.personal_information", first_name: current_user.first_name, last_name: current_user.last_name ,field_name: "Last Name")
          else
            history_description = I18n.t("history_notifications.custom_field.updated", user_first_name: current_user.first_name, user_last_name: current_user.last_name, field_name: "Last Name", employee_first_name: tempUser.first_name, employee_last_name: tempUser.last_name)
          end
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: history_description,
            attached_users: [tempUser.try(:id)]
          })
        end
        if params["preferred_name"] && tempUser.preferred_name != params["preferred_name"]
          if current_user.id == tempUser.id
            history_description = I18n.t("history_notifications.user.updated.personal_information", first_name: current_user.first_name, last_name: current_user.last_name ,field_name: "Preferred Name")
          else
            history_description = I18n.t("history_notifications.custom_field.updated", user_first_name: current_user.first_name, user_last_name: current_user.last_name, field_name: "Preferred Name", employee_first_name: tempUser.first_name, employee_last_name: tempUser.last_name)
          end
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: history_description,
            attached_users: [tempUser.try(:id)]
          })
        end
        if params["team_id"] && tempUser.try(:team).try(:id) != params["team_id"]
          if current_user.id == tempUser.id
            history_description = I18n.t("history_notifications.user.updated.personal_information", first_name: current_user.first_name, last_name: current_user.last_name ,field_name: "Department")
          else
            history_description = I18n.t("history_notifications.custom_field.updated", user_first_name: current_user.first_name, user_last_name: current_user.last_name, field_name: "Department", employee_first_name: tempUser.first_name, employee_last_name: tempUser.last_name)

          end
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: history_description,
            attached_users: [tempUser.try(:id)]
          })
        end
        if params["location_id"] && tempUser.try(:location).try(:id) != params["location_id"]
          if current_user.id == tempUser.id
            history_description = I18n.t("history_notifications.user.updated.personal_information", first_name: current_user.first_name, last_name: current_user.last_name ,field_name: "Location")
          else
            history_description = I18n.t("history_notifications.custom_field.updated", user_first_name: current_user.first_name, user_last_name: current_user.last_name, field_name: "Location", employee_first_name: tempUser.first_name, employee_last_name: tempUser.last_name)
          end
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: history_description,
            attached_users: [tempUser.try(:id)]
          })
        end
        if params["start_date"] && tempUser.start_date != Date.parse(params["start_date"])
          if current_user.id == tempUser.id
            history_description = I18n.t("history_notifications.user.updated.personal_information", first_name: current_user.first_name, last_name: current_user.last_name ,field_name: "Start Date")
          else
            history_description = I18n.t("history_notifications.custom_field.updated", user_first_name: current_user.first_name, user_last_name: current_user.last_name, field_name: "Start Date", employee_first_name: tempUser.first_name, employee_last_name: tempUser.last_name)
          end
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: history_description,
            attached_users: [tempUser.try(:id)]
          })
        end
        if params["title"] && tempUser.title != params["title"]
          if current_user.id == tempUser.id
            history_description = I18n.t("history_notifications.user.updated.personal_information", first_name: current_user.first_name, last_name: current_user.last_name ,field_name: "Job Title")
          else
            history_description = I18n.t("history_notifications.custom_field.updated", user_first_name: current_user.first_name, user_last_name: current_user.last_name, field_name: "Job Title", employee_first_name: tempUser.first_name, employee_last_name: tempUser.last_name)
          end
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: history_description,
            attached_users: [tempUser.try(:id)]
          })
        end
        if params["termination_type"] && tempUser.termination_type != params["termination_type"]
          if current_user.id == tempUser.id
            history_description = I18n.t("history_notifications.user.updated.personal_information", first_name: current_user.first_name, last_name: current_user.last_name ,field_name: "Termination Date")
          else
            history_description = I18n.t("history_notifications.custom_field.updated", user_first_name: current_user.first_name, user_last_name: current_user.last_name, field_name: "Termination Date", employee_first_name: tempUser.first_name, employee_last_name: tempUser.last_name)

          end
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: history_description,
            attached_users: [tempUser.try(:id)]
          })
        end
        if params["eligible_for_rehire"] && tempUser.eligible_for_rehire != params["eligible_for_rehire"]
          if current_user.id == tempUser.id
            history_description = I18n.t("history_notifications.user.updated.personal_information", first_name: current_user.first_name, last_name: current_user.last_name ,field_name: "Eligible For Rehire")
          else
            history_description = I18n.t("history_notifications.custom_field.updated", user_first_name: current_user.first_name, user_last_name: current_user.last_name, field_name: "Eligible For Rehire", employee_first_name: tempUser.first_name, employee_last_name: tempUser.last_name)
          end
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: history_description,
            attached_users: [tempUser.try(:id)]
          })
        end
        if params["manager"] && tempUser.try(:manager).try(:id) != params["manager"]["id"]
          if current_user.id == tempUser.id
            history_description = I18n.t("history_notifications.user.updated.personal_information", first_name: current_user.first_name, last_name: current_user.last_name ,field_name: "Manager")
          else
            history_description = I18n.t("history_notifications.custom_field.updated", user_first_name: current_user.first_name, user_last_name: current_user.last_name, field_name: "Manager", employee_first_name: tempUser.first_name, employee_last_name: tempUser.last_name)
          end
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: history_description,
            attached_users: [tempUser.try(:id)]
          })
        end
        if params["user_role_name"] && tempUser.user_role_name != params["user_role_name"]
          if current_user.id == tempUser.id
            history_description = I18n.t("history_notifications.user.updated.personal_information", first_name: current_user.first_name, last_name: current_user.last_name ,field_name: "Access Permission")
          else
            history_description = I18n.t("history_notifications.custom_field.updated", user_first_name: current_user.first_name, user_last_name: current_user.last_name, field_name: "Access Permission", employee_first_name: tempUser.first_name, employee_last_name: tempUser.last_name)
          end
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: history_description,
            attached_users: [tempUser.try(:id)]
          })
        end
        if params["buddy"] && tempUser.try(:buddy).try(:id) != params["buddy"]["id"]
          if current_user.id == tempUser.id
            history_description = I18n.t("history_notifications.user.updated.personal_information", first_name: current_user.first_name, last_name: current_user.last_name ,field_name: "Buddy")
          else
            history_description = I18n.t("history_notifications.custom_field.updated", user_first_name: current_user.first_name, user_last_name: current_user.last_name, field_name: "Buddy", employee_first_name: tempUser.first_name, employee_last_name: tempUser.last_name)
          end
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: history_description,
            attached_users: [tempUser.try(:id)]
          })
        end
        if params["personal_email"] && tempUser.try(:personal_email) != params["personal_email"]
          if current_user.id == tempUser.id
            history_description = I18n.t("history_notifications.user.updated.personal_information", first_name: current_user.first_name, last_name: current_user.last_name ,field_name: "Personal Email")
          else
            history_description = I18n.t("history_notifications.custom_field.updated", user_first_name: current_user.first_name, user_last_name: current_user.last_name, field_name: "Personal Email", employee_first_name: tempUser.first_name, employee_last_name: tempUser.last_name)
          end
          History.create_history({
           company: current_company,
           user_id: current_user.id,
           description: history_description,
           attached_users: [tempUser.try(:id)]
           })
        end
      end
    end
  end
end