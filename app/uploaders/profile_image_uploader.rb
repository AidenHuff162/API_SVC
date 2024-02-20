# encoding: utf-8

class ProfileImageUploader < ImageUploader

  version :square_thumb do
    process resize_to_fill: [150, 150]
  end

  version :thumb do
    process resize_to_fit: [150, 150]
  end

  def default_url(*args)
    ActionController::Base.helpers.asset_path('/fallback/' + ['default_profile_image.png'].compact.join('_'))
  end
end
