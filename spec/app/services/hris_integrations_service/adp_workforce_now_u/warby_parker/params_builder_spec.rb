require 'rails_helper'

RSpec.describe HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::ParamsBuilder do
  let(:company) { create(:company) }
  let(:adp_us) { create(:adp_integration, api_name: 'adp_wfn_us', company: company, meta: {location_id: ['all'], team_id: ['all'], employee_type: ['all'] }) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company, adp_wfn_us_id: '123') } 

  describe '#update_adp_from_sapling' do
    it 'should update ADP from Sapling' do
      data = HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::DataBuilder.new('US').build_applicant_onboard_data(user, adp_us)
      params = HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::ParamsBuilder.new.build_applicant_onboard_params(data)
      expect(params[:events][0][:data][:transform][:applicant][:person][:legalName][:givenName]).to eq(user.first_name)
    end
  end
end 