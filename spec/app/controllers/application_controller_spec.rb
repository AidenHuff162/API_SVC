require 'rails_helper'

describe ApplicationController, type: :controller do
  controller(ApplicationController) do
    def index
      render plain: 'index'
    end

    def unknown_format
      raise ActionController::UnknownFormat
    end

    def routing_error
      raise ActionController::RoutingError.new('Not Found')
    end

    def not_found
      ex = OpenStruct.new({message: 'error'})
      render json: { errors: [Errors::NotFound.new(ex.message).error] }, status: :not_found
    end
  end

  describe 'raise_not_found' do
    it "renders file public/404.html" do
      routes.draw { get "unknown_format" => "anonymous#unknown_format" }
      get :unknown_format
      expect(response.body).to eq(File.read('public/404.html'))
    end
  end

  specify 'ActionController::RoutingError will render file 403.html' do
    routes.draw { get "routing_error" => "anonymous#routing_error" }
    get :routing_error
    expect(response.body).to eq(File.read('public/403.html'))
  end

  specify 'not_found renders json' do
    routes.draw { get "not_found" => "anonymous#not_found" }
    get :not_found
    expect(response.headers["Content-Type"].include?("application/json")).to eq(true)
  end

  specify 'not_found renders status 404' do
    routes.draw { get "not_found" => "anonymous#not_found" }
    get :not_found
    expect(response.status).to eq(404)
  end

  describe '#info_for_paper_trail' do
    it 'will return hash with ip and user_agent' do
      get :index
      res = controller.info_for_paper_trail
      expect(res[:ip]).to eq(request.remote_ip)
      expect(res[:user_agent]).to eq(request.user_agent)
    end
  end

end
