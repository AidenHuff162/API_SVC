require 'rails_helper'

RSpec.describe Integrations::MigrateSimplePhoneDataToInternationalPhoneFormatJob, type: :job do

  let(:company) { create(:company, subdomain: 'rocketship') }

  before do
    @custom_field = company.custom_fields.first
    allow_any_instance_of(CustomFieldsService).to receive(:migrate_simple_phone_data_to_international_phone_format) {'Migrated'}
  end
  it "should migrate the migrate_simple_phone_data_to_international_phone_format " do
    response = Integrations::MigrateSimplePhoneDataToInternationalPhoneFormatJob.perform_now(company.id, @custom_field.id)
    expect(response).to eq('Migrated')
  end

  it "should not migrate the migrate_simple_phone_data_to_international_phone_format if field name not present" do
    response = Integrations::MigrateSimplePhoneDataToInternationalPhoneFormatJob.perform_now(company.id)
    expect(response).to_not eq("Migrated")
  end

  it "should not migrate the migrate_simple_phone_data_to_international_phone_format if company not present" do
    response = Integrations::MigrateSimplePhoneDataToInternationalPhoneFormatJob.perform_now(nil)
    expect(response).to_not eq("Migrated")
  end
end

