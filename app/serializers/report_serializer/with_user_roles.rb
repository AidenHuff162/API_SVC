module ReportSerializer
  class WithUserRoles < ActiveModel::Serializer
    attributes :id, :name, :user_role_ids, :super_admin_roles, :admin_roles, :created_at
    has_many :users, serializer: UserSerializer::HistoryUser

    def super_admin_roles
      company ||= @instance_options[:company] || object.company
      super_admin_count = company.user_roles.joins(:users).where(role_type: UserRole.role_types[:super_admin], id: object.user_role_ids).count
      "Super Admins (#{super_admin_count})"
    end

    def admin_roles
      company ||= @instance_options[:company] || object.company
      company.user_roles.where(role_type: UserRole.role_types[:admin], id: object.user_role_ids).joins("LEFT JOIN users on user_roles.id = users.user_role_id").group('user_roles.id').select(:name, :id, "COUNT(users.id)")
    end
  end
end
