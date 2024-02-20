# encoding: utf-8

class DisplayLogoImageUploader < ImageUploader

  version :thumb do
    process resize_to_fit: [150, 150]
  end

  def default_url(*args)
    ActionController::Base.helpers.asset_path('/assets/images/logos/' + ['sapling.png'].compact.join('_'))
  end
end
