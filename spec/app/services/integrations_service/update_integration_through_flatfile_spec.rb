require 'rails_helper'

RSpec.describe IntegrationsService::UpdateIntegrationThroughFlatfile do
  let!(:company) { create(:company) }
  let(:xero_integration_inventory) {create(:integration_inventory, display_name: 'Xero', status: 2, category: 0, data_direction: 1, enable_filters: false, api_identifier: 'xero')}
  let(:xero) {create(:integration_instance, api_identifier: 'xero', state: 'active', integration_inventory_id: xero_integration_inventory.id, name: 'Instance no.1', company_id: company.id)}
  let!(:current_user) { create(:user, state: :active, current_stage: :registered, role: :account_owner, company: company) }
  let!(:integration_valid_user_data) {['first_name', 'last_name', 'preferred_name', 'personal_email', 'email', 'start_date']}
  let!(:integration_invalid_user_data) {['about', 'linkedin', 'twitter']}

  describe "flatfile_api_calls" do

    context 'trigger_api_call_to_bamboo' do
      let!(:bamboo_integration) { FactoryGirl.create(:bamboohr_integration, company: company) }
      let!(:bamboo_user) { create(:user, state: :active, current_stage: :registered, role: :employee, bamboo_id: 'Bamboo-1234', company: company) }
      
      it "should_trigger_api_call_to_bamboo" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(bamboo_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_hr"], :size).by(6)
      end

      it "should_not_trigger_api_call_to_bamboo" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(bamboo_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_hr"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_one_login' do
      let!(:one_login_integration) { FactoryGirl.create(:one_login_integration_instance, company: company) }
      let!(:one_login_user) { create(:user, state: :active, current_stage: :registered, role: :employee, one_login_id: 'OneLogin-1234', company: company) }
      
      it "should_trigger_api_call_to_one_login" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(one_login_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["manage_one_login_integration"], :size).by(1)
      end

      it "should_not_trigger_api_call_to_one_login" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(one_login_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["manage_one_login_integration"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_workday' do
      let!(:workday_instance) { FactoryGirl.create(:workday_instance, company: company) }
      let!(:workday_user) { create(:user, state: :active, current_stage: :registered, role: :employee, workday_id: 'Workday-1234', company: company) }
      
      it "should_trigger_api_call_to_workday" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(workday_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_hr"], :size).by(1)
      end

      it "should_not_trigger_api_call_to_workday" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(workday_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_hr"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_namely' do
      let!(:namely_integration) { FactoryGirl.create(:namely_integration, company: company) }
      let!(:namely_user) { create(:user, state: :active, current_stage: :registered, role: :employee, namely_id: 'Namely-1234', company: company) }
      
      it "should_trigger_api_call_to_namely" do
        # expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(namely_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_hr"], :size).by(6)
      end

      it "should_not_trigger_api_call_to_namely" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(namely_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_hr"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_xero' do
      let!(:xero_integration) { FactoryGirl.create(:xero_integration, company: company) }
      let!(:xero_user) { create(:user, state: :active, current_stage: :registered, role: :employee, xero_id: 'Xero-1234', company: company) }
      
      it "should_trigger_api_call_to_xero" do
        xero.stub(:api_identifier) {'xero'}
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(xero_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_hr"], :size).by(3)
      end

      it "should_not_trigger_api_call_to_xero" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(xero_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_hr"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_okta' do
      let!(:okta_integration) { FactoryGirl.create(:okta_integration_instance, company: company) }
      let!(:okta_user) { create(:user, state: :active, current_stage: :registered, role: :employee, okta_id: 'Okta-1234', company: company) }
      
      it "should_trigger_api_call_to_okta" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(okta_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["manage_one_login_integration"], :size).by(1)
      end

      it "should_not_trigger_api_call_to_okta" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(okta_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["manage_one_login_integration"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_gsuite' do
      let!(:company) { create(:company, subdomain: 'warbyparker') }
      let!(:gsuite) { create(:gsuite_integration_instance, company: company)}
      let!(:gsuite_user) { create(:user, state: :active, current_stage: :registered, role: :employee, company: company) }
      
      it "should_trigger_api_call_to_gsuite" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(gsuite_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["manage_one_login_integration"], :size).by(1)
      end

      it "should_not_trigger_api_call_to_gsuite" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(gsuite_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["manage_one_login_integration"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_adfs' do
      let!(:adfs_integration) { FactoryGirl.create(:adfs_productivity_integration_instance, company: company) }
      let!(:adfs_user) { create(:user, state: :active, current_stage: :registered, role: :employee, active_directory_object_id: 'ADFS-1234', company: company) }
      
      it "should_trigger_api_call_to_adfs" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(adfs_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["manage_one_login_integration"], :size).by(6)
      end

      it "should_not_trigger_api_call_to_adfs" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(adfs_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["manage_one_login_integration"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_learn_upon' do
      let!(:learn_upon_inventory) { FactoryGirl.create(:learn_upon_integration_inventory).id }
      let!(:learn_upon) { create(:integration_instance, api_identifier: 'learn_upon', state: IntegrationInstance.states[:active], sync_status: IntegrationInstance.sync_statuses[:succeed], integration_inventory_id: learn_upon_inventory, name: 'Instance no.1', company_id: company.id, filters: {"location_id" => ["all"], "team_id" => ["all"], "employee_type" => ["all"]}) }
      let!(:learn_upon_user) { create(:user, state: :active, current_stage: :registered, role: :employee, learn_upon_id: 'LearnUpon-1234', company: company) }
      
      it "should_trigger_api_call_to_learn_upon" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(learn_upon_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["manage_learn_and_development_integration"], :size).by(1)
      end

      it "should_not_trigger_api_call_to_learn_upon" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(learn_upon_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["manage_learn_and_development_integration"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_lessonly' do
      let!(:lessonly_inventory) { FactoryGirl.create(:lessonly_integration_inventory).id }
      let!(:lessonly) { create(:integration_instance, api_identifier: 'lessonly', state: IntegrationInstance.states[:active], sync_status: IntegrationInstance.sync_statuses[:succeed], integration_inventory_id: lessonly_inventory, name: 'Instance no.1', company_id: company.id, filters: {"location_id" => ["all"], "team_id" => ["all"], "employee_type" => ["all"]}) }
      let!(:lessonly_user) { create(:user, state: :active, current_stage: :registered, role: :employee, lessonly_id: 'Lessonly-1234', company: company) }
      
      it "should_trigger_api_call_to_lessonly" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(lessonly_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["manage_learn_and_development_integration"], :size).by(1)
      end

      it "should_not_trigger_api_call_to_lessonly" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(lessonly_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["manage_learn_and_development_integration"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_deputy' do
      let!(:deputy_inventory) { FactoryGirl.create(:deputy_integration_inventory).id }
      let!(:deputy) { create(:integration_instance, api_identifier: 'deputy', state: IntegrationInstance.states[:active], sync_status: IntegrationInstance.sync_statuses[:succeed], integration_inventory_id: deputy_inventory, name: 'Instance no.1', company_id: company.id, filters: {"location_id" => ["all"], "team_id" => ["all"], "employee_type" => ["all"]}) }
      let!(:deputy_user) { create(:user, state: :active, current_stage: :registered, role: :employee, deputy_id: 'Deputy-1234', company: company) }
      
      it "should_trigger_api_call_to_deputy" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(deputy_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["manage_deputy_integration"], :size).by(1)
      end

      it "should_not_trigger_api_call_to_deputy" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(deputy_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["manage_deputy_integration"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_deputy' do
      let!(:deputy_inventory) { FactoryGirl.create(:deputy_integration_inventory).id }
      let!(:deputy) { create(:integration_instance, api_identifier: 'deputy', state: IntegrationInstance.states[:active], sync_status: IntegrationInstance.sync_statuses[:succeed], integration_inventory_id: deputy_inventory, name: 'Instance no.1', company_id: company.id, filters: {"location_id" => ["all"], "team_id" => ["all"], "employee_type" => ["all"]}) }
      let!(:deputy_user) { create(:user, state: :active, current_stage: :registered, role: :employee, deputy_id: 'Deputy-1234', company: company) }
      
      it "should_trigger_api_call_to_deputy" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(deputy_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["manage_deputy_integration"], :size).by(1)
      end

      it "should_not_trigger_api_call_to_deputy" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(deputy_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["manage_deputy_integration"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_trinet' do
      let!(:trinet_inventory) { FactoryGirl.create(:trinet_integration_inventory).id }
      let!(:trinet) { create(:integration_instance, api_identifier: 'trinet', state: IntegrationInstance.states[:active], sync_status: IntegrationInstance.sync_statuses[:succeed], integration_inventory_id: trinet_inventory, name: 'Instance no.1', company_id: company.id, filters: {"location_id" => ["all"], "team_id" => ["all"], "employee_type" => ["all"]}) }
      let!(:trinet_user) { create(:user, state: :active, current_stage: :registered, role: :employee, trinet_id: 'Trinet-1234', company: company) }
      
      it "should_trigger_api_call_to_trinet" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(trinet_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_hr"], :size).by(1)
      end

      it "should_not_trigger_api_call_to_trinet" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(trinet_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_hr"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_fifteen_five' do
      let!(:fifteen_five_inventory) { FactoryGirl.create(:fifteen_five_integration_inventory).id }
      let!(:fifteen_five) { create(:integration_instance, api_identifier: 'fifteen_five', state: IntegrationInstance.states[:active], sync_status: IntegrationInstance.sync_statuses[:succeed], integration_inventory_id: fifteen_five_inventory, name: 'Instance no.1', company_id: company.id, filters: {"location_id" => ["all"], "team_id" => ["all"], "employee_type" => ["all"]}) }
      let!(:fifteen_five_user) { create(:user, state: :active, current_stage: :registered, role: :employee, fifteen_five_id: 'FifteenFive-1234', company: company) }
      
      it "should_trigger_api_call_to_fifteen_five" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(fifteen_five_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["manage_deputy_integration"], :size).by(1)
      end

      it "should_not_trigger_api_call_to_fifteen_five" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(fifteen_five_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["manage_deputy_integration"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_gusto' do
      let!(:gusto_inventory) { FactoryGirl.create(:gusto_integration_inventory).id }
      let!(:gusto) { create(:integration_instance, api_identifier: 'gusto', state: IntegrationInstance.states[:active], sync_status: IntegrationInstance.sync_statuses[:succeed], integration_inventory_id: gusto_inventory, name: 'Instance no.1', company_id: company.id, filters: {"location_id" => ["all"], "team_id" => ["all"], "employee_type" => ["all"]}) }
      let!(:gusto_user) { create(:user, state: :active, current_stage: :registered, role: :employee, gusto_id: 'Gusto-1234', company: company) }

      it "should_trigger_api_call_to_gusto" do
        company.stub(:gusto_feature_flag) {true}
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(gusto_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_hr"], :size).by(1)
      end

      it "should_not_trigger_api_call_to_gusto" do
        company.stub(:gusto_feature_flag) {true}
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(gusto_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_hr"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_lattice' do
      let!(:lattice_inventory) { FactoryGirl.create(:lattice_integration_inventory).id }
      let!(:lattice) { create(:integration_instance, api_identifier: 'lattice', state: IntegrationInstance.states[:active], sync_status: IntegrationInstance.sync_statuses[:succeed], integration_inventory_id: lattice_inventory, name: 'Instance no.1', company_id: company.id, filters: {"location_id" => ["all"], "team_id" => ["all"], "employee_type" => ["all"]}) }
      let!(:lattice_user) { create(:user, state: :active, current_stage: :registered, role: :employee, lattice_id: 'Lattice-1234', company: company) }

      it "should_trigger_api_call_to_lattice" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(lattice_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["manage_deputy_integration"], :size).by(1)
      end

      it "should_not_trigger_api_call_to_lattice" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(lattice_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["manage_deputy_integration"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_paychex' do
      let!(:paychex_inventory) { FactoryGirl.create(:paychex_integration_inventory).id }
      let!(:paychex) { create(:integration_instance, api_identifier: 'paychex', state: IntegrationInstance.states[:active], sync_status: IntegrationInstance.sync_statuses[:succeed], integration_inventory_id: paychex_inventory, name: 'Instance no.1', company_id: company.id, filters: {"location_id" => ["all"], "team_id" => ["all"], "employee_type" => ["all"]}) }
      let!(:paychex_user) { create(:user, state: :active, current_stage: :registered, role: :employee, paychex_id: 'Paychex-1234', company: company) }

      it "should_trigger_api_call_to_paychex" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(paychex_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_hr"], :size).by(1)
      end

      it "should_not_trigger_api_call_to_paychex" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(paychex_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_hr"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_peakon' do
      let!(:peakon_inventory) { FactoryGirl.create(:peakon_integration_inventory).id }
      let!(:peakon) { create(:integration_instance, api_identifier: 'peakon', state: IntegrationInstance.states[:active], sync_status: IntegrationInstance.sync_statuses[:succeed], integration_inventory_id: peakon_inventory, name: 'Instance no.1', company_id: company.id, filters: {"location_id" => ["all"], "team_id" => ["all"], "employee_type" => ["all"]}) }
      let!(:peakon_user) { create(:user, state: :active, current_stage: :registered, role: :employee, peakon_id: 'Peakon-1234', company: company) }

      it "should_trigger_api_call_to_peakon" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(peakon_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["manage_deputy_integration"], :size).by(4)
      end

      it "should_not_trigger_api_call_to_peakon" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(peakon_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["manage_deputy_integration"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_adp' do
      let!(:adp_integration) { FactoryGirl.create(:adp_wfn_us_integration, company: company) }
      let!(:adp_user) { create(:user, state: :active, current_stage: :registered, role: :employee, adp_wfn_us_id: 'ADP-US-1234', company: company) }

      it "should_trigger_api_call_to_adp" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(adp_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(5)
      end

      it "should_not_trigger_api_call_to_adp" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(adp_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_adp"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_kallidus' do
      let!(:kallidus_inventory) { FactoryGirl.create(:kallidus_learn_integration_inventory).id }
      let!(:kallidus) { create(:integration_instance, api_identifier: 'kallidus_learn', state: IntegrationInstance.states[:active], sync_status: IntegrationInstance.sync_statuses[:succeed], integration_inventory_id: kallidus_inventory, name: 'Instance no.1', company_id: company.id, filters: {"location_id" => ["all"], "team_id" => ["all"], "employee_type" => ["all"]}) }
      let!(:kallidus_user) { create(:user, state: :active, current_stage: :registered, role: :account_owner, company: company) }
      
      it "should_trigger_api_call_to_kallidus" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(kallidus_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["manage_learn_and_development_integration"], :size).by(1)
      end

      it "should_not_trigger_api_call_to_kallidus" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(kallidus_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["manage_learn_and_development_integration"], :size).by(0)
      end
    end

    context 'trigger_api_call_to_paylocity' do
      let!(:paylocity_inventory) { FactoryGirl.create(:paylocity_integration_inventory).id }
      let!(:paylocity) { create(:integration_instance, api_identifier: 'paylocity', state: IntegrationInstance.states[:active], sync_status: IntegrationInstance.sync_statuses[:succeed], integration_inventory_id: paylocity_inventory, name: 'Instance no.1', company_id: company.id, filters: {"location_id" => ["all"], "team_id" => ["all"], "employee_type" => ["all"]}) }
      let!(:paylocity_user) { create(:user, state: :active, current_stage: :registered, role: :employee, paylocity_id: 'Paylocity-1234', company: company) }

      it "should_trigger_api_call_to_paylocity" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(paylocity_user, integration_valid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_hr"], :size).by(1)
      end

      it "should_not_trigger_api_call_to_paylocity" do
        expect{::IntegrationsService::UpdateIntegrationThroughFlatfile.new(paylocity_user, integration_invalid_user_data).perform}.to change(Sidekiq::Queues["update_employee_to_hr"], :size).by(0)
      end
    end
  end
end
