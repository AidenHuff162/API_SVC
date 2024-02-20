require 'rails_helper'

class CompanyMiddlewareTestApp
  def call(env)
    @env = env

    [200, {'Content-Type' => 'text/plain'}, ['OK']]
  end

  def [](key)
    @env[key]
  end
end

RSpec.describe CompanyMiddleware do
  let(:app) { CompanyMiddlewareTestApp.new }
  let(:middleware) { CompanyMiddleware.new(app) }
  let(:request) { Rack::MockRequest.new(middleware) }

  context 'when company exists' do
    context 'by subdomain' do
      let!(:company) { create(:company, subdomain: 'example') }

      before(:each) { request.get(path, 'SERVER_NAME' => "example.#{ENV['DEFAULT_HOST']}") }

      context 'when assets requested' do
        let(:path) { '/assets/some_resource.jpg' }

        it 'not sets CURRENT_COMPANY' do
          expect(app['CURRENT_COMPANY']).to be_nil
        end
      end

      context 'when not assets requested' do
        let(:path) { '/' }

        it 'sets CURRENT_COMPANY' do
          expect(app['CURRENT_COMPANY'].id).to eq(company.id)
        end
      end
    end
  end

  context 'when company not exists' do
    before(:each) { request.get('/') }

    it 'not sets Houser-Object' do
      expect(app['CURRENT_COMPANY']).to be_nil
    end
  end
end
