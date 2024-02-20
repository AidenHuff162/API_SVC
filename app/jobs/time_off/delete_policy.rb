include Sidekiq::Worker

module TimeOff
  class DeletePolicy < ApplicationJob
    queue_as :pto_activities

    def perform id
      @pto_policy = PtoPolicy.with_deleted.find(id)
      remove_reports
      remove_associated_objects
    end

    private

    def remove_associated_objects
      associations_to_remove.each do |association|
        if [:assigned_pto_policies, :unassigned_pto_policies, :pto_requests, :policy_tenureships].include? association
          @pto_policy.send(association).destroy_all
        end
      end
    end

    def associations_to_remove
      associations = PtoPolicy.reflect_on_all_associations.map(&:name)
      associations.delete(:users)
      associations.delete(:company)
      associations
    end
    
    def remove_reports
      @pto_policy.company.reports.time_off.try(:each) do |report|
        report.destroy! if report_of_current_policy(report) 
      end
    end

    def report_of_current_policy report
      report.meta.present? && report.meta["pto_policy"].present? && report.meta["pto_policy"] == @pto_policy.id
    end
  end
end