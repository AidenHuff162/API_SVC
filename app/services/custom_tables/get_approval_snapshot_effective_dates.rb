module CustomTables
  class GetApprovalSnapshotEffectiveDates

    attr_reader :params, :current_company

    def initialize params, current_company
      @params = params
      @current_company = current_company
      @response_array = []
    end

    def perform
      get_min_effective_date_wrt_ctus
      @response_array
    end

    private

    def get_min_effective_date_wrt_ctus
      user_ids = JSON.parse(@params["user_array"])["userIdArray[]"]
      user_ids.each do |id|
        user = @current_company.users.find_by_id(id)
        if user.present?
          ctus = user.custom_table_user_snapshots.joins(:custom_table).where(custom_tables: {is_approval_required: true}).group(:custom_table_id).maximum(:effective_date)
          response_element = {}
          response_element[:user_id] = id
          response_element[:ctus] = ctus
          @response_array << response_element
        end
      end
    end

  end
end