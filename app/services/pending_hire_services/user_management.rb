module PendingHireServices
  class UserManagement
    def initialize(pending_hire, event)
      @pending_hire = pending_hire
      @event = event
    end

    ATTRIBUTES_NAME = %w[first_name last_name company_id title location_id team_id start_date personal_email manager_id preferred_name]


    def call
      event == 'create' ? create_user : update_user
    end

    private

    attr_reader :pending_hire, :event

    def create_user
      params = create_incomplete_user_params
      user_form = UserForm.new(params)
      user_form.save!
      pending_hire.update!(user_id: user_form.user.id)
    end

    def update_user
      params = create_incomplete_user_params
      params[:id] = pending_hire.user_id
      user_form = UserForm.new(params)
      user_form.save!
    end

    def create_incomplete_user_params
      user_params_hash = {}
      feature_flag = pending_hire.company.smart_assignment_2_feature_flag
      configuration = pending_hire.company.smart_assignment_configuration.meta.dig('smart_assignment')
      smart_assignment = feature_flag ? configuration : pending_hire.company.sa_disable

      ATTRIBUTES_NAME.each do |name|
        user_params_hash[name.to_sym] = pending_hire.send(name.to_sym)
      end

      user_params_hash.merge!(current_stage: User.current_stages[:incomplete], smart_assignment: smart_assignment)
      user_params_hash
    end
  end
end