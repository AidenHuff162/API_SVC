module SetAdminAccessToken
  extend ActiveSupport::Concern

  def set_access_token_on_front_end(resource)
    ActiveAdmin::SetEncryptedAccessToken.new(resource.id).perform
    cookies[:admin_access_token] = resource.reload.access_token
  end
  
end