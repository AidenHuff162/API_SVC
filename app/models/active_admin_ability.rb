class ActiveAdminAbility
  include CanCan::Ability

  def initialize(user)
    user ||= AdminUser.new

    if user.class == AdminUser && user.super_user?
      can :manage, :all
    elsif user.class == AdminUser
      register_role_based_abilities(user)
    end
    
    # Everyone can read the page of Permission Deny
    can :read, ActiveAdmin::Page, name: 'Dashboard'

  end


  def register_role_based_abilities(user)
    (::ActiveAdmin::Permission.indexed_cache[user.role] || []).select(&:active?).each do |permission|
      send(*permission.to_condition)
    end
  end
end
