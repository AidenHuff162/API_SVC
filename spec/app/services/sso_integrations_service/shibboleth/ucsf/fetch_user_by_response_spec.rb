require 'rails_helper'

RSpec.describe SsoIntegrationsService::Shibboleth::UCSF::FetchUserByResponse do
  let(:user) { create(:user) }
  let!(:custom_field) {create(:custom_field,:employee_number, company: user.company)}
  let!(:custom_field_value) {create(:custom_field_value, :employee_number_field_value, user: user, custom_field: custom_field)}

  describe 'get user by response' do
    it 'should return user' do
      attributes = double('attributes', attributes: {id: ['12345678'], email: [user.email]}) 
      response = double('response', attributes: attributes)
      allow(attributes).to receive(:values).and_return([[12345678], [user.email]])
      result = SsoIntegrationsService::Shibboleth::UCSF::FetchUserByResponse.new(response, user.company).perform 
      expect(result.id).to eq(user.id)
    end
  end
end
