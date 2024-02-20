class CreateOrganizationChartJob
  include Sidekiq::Worker
  sidekiq_options :queue => :generate_org_chart, :retry => false, lock: :until_executed

  def perform(company_id=nil)
    if company_id && company_id > 0
      puts "------------ Creating Organization Chart via Job ------------"
      begin
        Company.find_by(id: company_id).generate_organization_tree()
      rescue Exception => e
        puts "--------------------- Exception in Create Organization Chart Job --------------------"
        puts company_id
        puts e
      end
    end
  end
end
