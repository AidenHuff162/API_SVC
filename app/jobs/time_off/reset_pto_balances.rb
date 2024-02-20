module TimeOff
  class ResetPTOBalances
    include Sidekiq::Worker
    sidekiq_options queue: :pto_activities

    def perform user_id
      user = User.find_by(id: user_id)
      user.assigned_pto_policies.joins(:pto_policy).where(pto_policies: {unlimited_policy: false, is_enabled: true}).each do |ap|
        ap.reset_policy(user.company.time.to_date)
      end if user.present?
    end
  end
end
