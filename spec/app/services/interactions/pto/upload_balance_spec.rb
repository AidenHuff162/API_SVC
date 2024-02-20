require 'rails_helper'

RSpec.describe Interactions::Pto::UploadBalance do
  let(:company) {create(:company)}
  it 'should enque a job in sidekiq' do
    expect{ Interactions::Pto::UploadBalance.new({}, company).perform }.to change(Sidekiq::Queues["pto_activities"], :size).by(1)
  end
end
