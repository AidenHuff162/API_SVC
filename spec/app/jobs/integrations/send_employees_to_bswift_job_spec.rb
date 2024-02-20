require 'rails_helper'

RSpec.describe Integrations::SendEmployeesToBswiftJob, type: :job do

  let(:company) { create(:company, subdomain: 'rocketship') }

  before do
    @custom_field = company.custom_fields.first
    allow_any_instance_of(BswiftService::Main).to receive(:perform) {'Service Executed'}
  end
  it "should migrate the BswiftService " do
    response = Integrations::SendEmployeesToBswiftJob.new.perform(company.id)
    expect(response).to eq('Service Executed')
  end

  it "should not migrate the BswiftService if company not present" do
    response = Integrations::SendEmployeesToBswiftJob.new.perform(nil)
    expect(response).to eq(nil)
  end
end

