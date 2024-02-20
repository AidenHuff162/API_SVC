module ReportSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :name, :meta, :permanent_fields, :last_view, :created_at, :user_role_ids, :custom_tables, :report_type, :user_roles

    has_many :users, serializer: UserSerializer::HistoryUser
    has_many :custom_field_reports
    belongs_to :sftp, serializer: SftpSerializer::Simple

    def user_roles
      Company.find_by(id: object.company_id).user_roles.where(id: object.user_role_ids).pluck(:id, :name)
    end
  end
end
