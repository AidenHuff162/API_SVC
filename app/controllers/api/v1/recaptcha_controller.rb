module Api
  module V1
    class RecaptchaController < ApiController
      before_action :require_company!

      def verify
        success = { success: false }
        g_recaptcha_response = params[:response]

        response = HTTParty.post("https://www.google.com/recaptcha/api/siteverify?secret=#{ENV['RECAPTCHA_SECRET_KEY']}&response=#{g_recaptcha_response}")

        success[:success] = JSON.parse(response.body)['success']
        respond_with success
      end
    end
  end
end
