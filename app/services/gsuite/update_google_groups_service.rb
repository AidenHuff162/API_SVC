class UpdateGoogleGroupsService
  def perform
    companies = Company.joins(:integration_instances).where("integration_instances.api_identifier = 'gsuite' AND state=1").where.not("companies.subdomain = 'warbyparker'")
    companies.try(:each) do |company| 
      if company.google_groups_feature_flag.present? && company.get_gsuite_account_info.present?
        ::Gsuite::ManageAccount.new.get_gsuite_ou(company)
        ::Gsuite::ManageAccount.new.get_gsuite_groups(company)
      end
    end
  end
end