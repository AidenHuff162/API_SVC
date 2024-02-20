module CustomTables
  class PowerUpdateWorker
    include Sidekiq::Worker
    sidekiq_options queue: :manage_custom_snapshots, retry: false, backtrace: true

    def perform params, first_name, company_name, company_id, email, current_user_id
      CustomTableUserSnapshot.bypass_approval = true
      logger.info "WORKEEEEEEEEERRR \n"*12
      custom_table = CustomTable.find_by(id: params.first['custom_table_id'])
      params.each { |param| param['request_state'] = CustomTableUserSnapshot.request_states[:approved] } if custom_table && custom_table.is_approval_required.present? && params.present?
      CustomTableUserSnapshot.create(params)
      CustomTables::CreateHistoryForPowerUpdate.new(company_id, current_user_id, first_name, params.first['custom_table_id'], params.size).perform
      CustomTableMailer.send_power_update_confirmation_email(first_name, email, company_id, company_name, params.size, custom_table.try(:name)).deliver_now! unless Rails.env.test?
    end

  end
end
