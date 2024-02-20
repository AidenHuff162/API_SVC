require 'rails_helper'

RSpec.describe ErrorsController, type: :controller do

  describe "#not_found" do
    it "should render not found template" do
      get :not_found
      expect(response).to render_template("not_found")
    end
  end
end
