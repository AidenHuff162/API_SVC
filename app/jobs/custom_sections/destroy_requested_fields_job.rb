module CustomSections
  class DestroyRequestedFieldsJob
    include Sidekiq::Worker
    sidekiq_options queue: :manage_custom_snapshots, retry: false, backtrace: true

    def perform(cf_ids, pf_ids, company_id)
      CustomSections::RequestedFieldsDestroyManagement.new.destroy_requested_fields_on_profile_template_update(cf_ids, pf_ids, company_id)
    end
  end
end
