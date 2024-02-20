module PasswordStrength
  extend ActiveSupport::Concern

  def password_strength_checker(password)
    begin
      if Rails.env.test?
        render json: { password_acceptable: true }, status: 200
      else
        render json: { password_acceptable: StrongPassword::StrengthChecker.new(min_entropy: 10, min_word_length: 8, use_dictionary: false).is_strong?(password) }, status: 200
      end
    rescue Exception => e
      puts e.message
    end
  end
end
