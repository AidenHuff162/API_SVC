require 'rails_helper'

RSpec.describe SetUrlOptions do
  let(:options) { { subdomain: 'foo' } }

  subject { SetUrlOptions.new(company, options) }

  before(:each) { subject.call }

  context 'when company nil' do
    let(:company) { nil }

    it 'deletes subdomain from options' do
      expect(options[:subdomain]).to be_nil
    end

    it 'sets default host as host to options' do
      expect(options[:host]).to eq(ENV['DEFAULT_HOST'])
    end
  end

  context 'when company has domain attribute' do
    let(:company) { create(:company) }

    it 'deletes subdomain from options' do
      expect(options[:subdomain]).to be_nil
    end

    it 'sets company domain as host to options' do
      expect(options[:host]).to eq(company.domain)
    end
  end
end
