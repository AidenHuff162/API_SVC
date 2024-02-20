module Interactions
  module HistoryLog
    class CompanyHistoryLog
      def self.log(current_company,company,current_user_id)
        if company[:name] && current_company.name != company[:name]
          history_description = I18n.t('history_notifications.company.setting_updated', field: 'Company Name')
          History.create_history({
              company: current_company,
              user_id: current_user_id,
              description: history_description
            })
        end

        if company[:email] && current_company.email != company[:email]
          history_description = I18n.t('history_notifications.company.setting_updated', field: 'Company Email')
          History.create_history({
              company: current_company,
              user_id: current_user_id,
              description: history_description
            })
        end

        if company[:brand_color] && current_company.brand_color != company[:brand_color]
          history_description = I18n.t('history_notifications.company.setting_updated', field: 'Company Brand Color')
          History.create_history({
              company: current_company,
              user_id: current_user_id,
              description: history_description
            })
        end

        if company[:bio] && current_company.bio != company[:bio]
          history_description = I18n.t('history_notifications.company.setting_updated', field: 'Company\'s Bio')
          History.create_history({
              company: current_company,
              user_id: current_user_id,
              description: history_description
            })
        end

        if company[:time_zone] && current_company.time_zone != company[:time_zone]
          history_description = I18n.t('history_notifications.company.setting_updated', field: 'Company\'s Time Zone')
          History.create_history({
              company: current_company,
              user_id: current_user_id,
              description: history_description
            })
        end

        if company[:company_video] && current_company.company_video != company[:company_video]
          history_description = I18n.t('history_notifications.company.setting_updated', field: 'Company\'s Video')
          History.create_history({
              company: current_company,
              user_id: current_user_id,
              description: history_description
            })
        end

        if company[:preboarding_note] && current_company.preboarding_note != company[:preboarding_note]
          history_description = I18n.t('history_notifications.company.setting_updated', field: 'Company\'s Preboarding Note')
          History.create_history({
              company: current_company,
              user_id: current_user_id,
              description: history_description
            })
        end

        if company[:timeout_interval] && current_company.timeout_interval != company[:timeout_interval].to_i
          history_description = I18n.t('history_notifications.company.setting_updated', field: 'Sapling\'s session ')
          History.create_history({
              company: current_company,
              user_id: current_user_id,
              description: history_description
            })
        end

        if company[:display_name_format] && current_company.display_name_format != company[:display_name_format].to_i
          history_description = I18n.t('history_notifications.company.setting_updated', field: 'Sapling\'s Display Name Format ')
          History.create_history({
              company: current_company,
              user_id: current_user_id,
              description: history_description
            })
        end

      end
    end
  end
end
