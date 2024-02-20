# frozen_string_literal: true

module CustomAuthentication
  extend ActiveSupport::Concern
  include DeviseTokenAuth::Concerns::SetUserByToken

  # bypassing current user if ids_authetication_feature_flag is enabled
  def current_user
    if current_company&.ids_authentication_feature_flag && request.headers['Authorization']
      authenticate_by_ids_token
    else
      super
    end
  end

  private

  def current_company
    current_company ||= request.env['CURRENT_COMPANY']
  end

  def authenticate_by_ids_token
    origin = request.headers['Origin']
    access_token = request.headers['Authorization']&.split&.last
    return unless access_token

    IdentityServer::Authenticator.new({ current_company: current_company, access_token: access_token, origin: origin }).perform
  end
end
