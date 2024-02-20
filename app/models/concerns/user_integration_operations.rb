module UserIntegrationOperations
  extend ActiveSupport::Concern

  included do
    after_save { deactivate_integration_profiles( [], [ 'learn_upon', 'fifteen_five', 'peakon', 'deputy', 'lattice', 'kallidus_learn', 'namely'] ) if ((self.saved_change_to_current_stage? && self.departed? && (self.termination_date.present? || 
      self.last_day_worked.present?)) || (self.saved_change_to_state? && self.inactive?)) }

    after_commit { deactivate_integration_profiles( [ 'learn_upon', 'kallidus_learn'], ['fifteen_five', 'peakon'] ) if ((self.saved_change_to_last_day_worked? && self.last_day_worked.present? && self.last_day_worked > Date.today) || 
      (self.saved_change_to_state? && self.inactive?) || (self.saved_change_to_current_stage? && self.stage_offboarding? && self.last_day_worked.present?)) }

    # after_save { reactivate_integration_profiles if self.saved_change_to_is_rehired? && self.is_rehired.present? }
    after_destroy { delete_integration_profiles(['fifteen_five', 'peakon']) }
    after_real_destroy { delete_integration_profiles(['fifteen_five', 'peakon']) }
    
    after_save { update_integration_profiles(['fifteen_five']) if self.saved_change_to_state? && self.active?}
    after_commit { deactivate_integration_profiles(['peakon']) if self.peakon_id.present? && ((self.saved_change_to_current_stage? && self.termination_date.present? && self.departed?) || self.saved_change_to_state?) }
    after_save { deactivate_integration_profiles(['deputy']) if (self.saved_change_to_current_stage? && self.termination_date.present? && self.departed?) }
  end

  def create_integration_profiles(included_list = [], excluded_list = [], options = {})
    ::IntegrationsService::UserIntegrationOperationsService.new(self, included_list, excluded_list, options).perform('create')
  end

  def update_integration_profiles(included_list = [], excluded_list = [], options = {})
    ::IntegrationsService::UserIntegrationOperationsService.new(self, included_list, excluded_list, options).perform('update')
  end

  def reactivate_integration_profiles(included_list = [], excluded_list = [], options = {})
    ::IntegrationsService::UserIntegrationOperationsService.new(self, included_list, excluded_list, options).perform('reactivate')
  end

  def deactivate_integration_profiles(included_list = [], excluded_list = [], options = {})
    ::IntegrationsService::UserIntegrationOperationsService.new(self, included_list, excluded_list, options).perform('deactivate')
  end

  def delete_integration_profiles(included_list = [], excluded_list = [], options = {})
    ::IntegrationsService::UserIntegrationOperationsService.new(self, included_list, excluded_list, options).perform('delete')
  end
end
