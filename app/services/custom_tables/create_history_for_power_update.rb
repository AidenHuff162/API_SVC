module CustomTables
  class CreateHistoryForPowerUpdate
    attr_reader :company_id, :user_id, :user_first_name, :custom_table_id, :updated_records_count

    def initialize company_id, user_id, user_first_name, custom_table_id, updated_records_count
      @company = Company.find(company_id)
      @first_name = user_first_name
      @user_id = user_id
      @custom_table_id = custom_table_id
      @record_count = updated_records_count
    end

    def perform
      History.create(company_id: @company.id, user_id: @user_id, description: I18n.t("history_notifications.custom_table_user_snapshot.bulk_created", name: @first_name, table_name: get_custom_table_name, record_count: @record_count))
    end

    private

    def get_custom_table_name
      @company.custom_tables.find(@custom_table_id).name
    end

  end
end