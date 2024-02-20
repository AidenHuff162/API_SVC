class ProfileSerializer::Permitted < ActiveModel::Serializer
  attributes :id, :user_id, :facebook, :twitter, :linkedin, :about_you, :github

  def github
    object.get_profile_info(scope[:current_user], 'gh')
  end

  def linkedin
    object.get_profile_info(scope[:current_user], 'lin')
  end

  def twitter
    object.get_profile_info(scope[:current_user], 'twt')
  end

  def about_you
    object.get_profile_info(scope[:current_user], 'abt')
  end
end
