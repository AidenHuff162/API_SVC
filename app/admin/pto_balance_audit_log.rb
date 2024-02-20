ActiveAdmin.register PtoBalanceAuditLog do
  actions :index
  belongs_to :user
  includes assigned_pto_policy: :user

  filter :balance_updated_at

  index do
    selectable_column
    column :id
    column :balance_updated_at
    column "Description" do |object|
      h4 "#{object.assigned_pto_policy.pto_policy.name}"
      "#{object.description}"
    end
    column :"Used (-)" do |object|
      object.balance_used.present? ? "#{object.balance_used.round(2)} hours" : "0 hours"
    end
    column :"Accrued (+)" do |object|
      object.balance_added.present? ? "#{object.balance_added.round(2)} hours" : "0 hours"
    end
    column :"Balance" do |object|
      object.balance.present? ? "#{object.balance.round(2)} hours" : "0 hours"
    end
  end

end
