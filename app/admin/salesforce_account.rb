ActiveAdmin.register SalesforceAccount do
  config.sort_order = 'account_name_asc'
  config.batch_actions = false
  actions :all, :except => [:delete, :destroy, :create, :new]

  filter :account_name
  filter :contract_end_date
  filter :contract_end_notify_date

  index do
    selectable_column
    id_column
    column 'Sapling Company', :company
    column 'Salesforce Account', :account_name

    actions
  end

  show do
    attributes_table do
      row 'Sapling  Company', &:company
      row 'Salesforce Account', &:account_name
      row 'Salesforce Account ID', &:salesforce_id
      row 'MAU', &:mau
      row 'MRR ($)', &:mrr
      row 'CAB member', &:cab_member
      row 'Customer Until', &:contract_end_date
      row :contract_end_notify_date
      row 'Headcount', &:total_headcount
      # row 'Last Week Headcount', &:last_week_headcount
      # row 'This Week Headcount', &:this_week_headcount
      row 'Week Over Week Headcount Change (%)', &:weekly_headcount_change
    end
  end

  form html: {id: 'salesforce_account', data: {parsley_validate: true} } do |f|
    f.semantic_errors *f.object.errors.keys
    f.inputs "Salesforce Account Details" do
      if f.object.new_record?
        f.input :company_id, as: :select, :collection => Company.all_companies_alphabeticaly.pluck(:name, :id), input_html: {required: ''}
      end

      f.input :account_name, input_html: { required: '' }
      f.input :salesforce_id
      f.input :mau
      f.input :mrr, label: 'MRR ($)'
      f.input :cab_member
      f.input :contract_end_date, label: 'Customer Until'
      f.input :contract_end_notify_date
      # f.input :total_headcount, label: 'Headcount'
      # f.input :last_week_headcount, label: 'Last Week Headcount'
      # f.input :this_week_headcount, label: 'This Week Headcount'
      # f.input :weekly_headcount_change, label: 'Week Over Week Headcount Change (%)'
    end
    f.actions
  end
end

