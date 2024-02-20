module ReportSerializer
  class FilterData < ActiveModel::Serializer
    type :report

    attributes :id, :name, :meta, :created_at, :user_role_ids, :user_roles, :report_type, :sftp_id

    has_many :users, serializer: UserSerializer::ReportDisplay

    def user_roles
      Company.find_by(id: object.company_id).user_roles.where(id: object.user_role_ids).pluck(:id, :name)
    end
  end
end
