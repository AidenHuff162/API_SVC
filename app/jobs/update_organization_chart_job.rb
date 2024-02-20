class UpdateOrganizationChartJob
  include Sidekiq::Worker
  sidekiq_options :queue => :generate_org_chart, :retry => false, lock: :until_executed

  def perform(user_id, options={})
    if user_id
      puts "------------ Updating Organization Chart via Job ------------"
      user = User.find_by(id: user_id)
      begin
        user.company.update_organization_tree(user_id, options.deep_symbolize_keys) if user
      rescue Exception => e
        puts "--------------------- Exception in Update Organization Chart Job --------------------"
        puts user.company_id if user
        puts e
      end
    end
  end
end
