class ActiveAdminLogging < ApplicationRecord
  belongs_to :admin_user
  belongs_to :company
  belongs_to :user
  belongs_to :company_email
  belongs_to :version
end
