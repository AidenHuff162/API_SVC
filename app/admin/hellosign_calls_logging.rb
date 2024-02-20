ActiveAdmin.register HellosignCall do
  config.batch_actions = false

  filter :company
  filter :api_end_point
  filter :error_name
  filter :state, as: :select, multiple: true, collection: HellosignCall.states
  filter :call_type, as: :select, multiple: true, collection: HellosignCall.call_types
  filter :priority, as: :select, multiple: true, collection: HellosignCall.priorities
  filter :error_category, as: :select, multiple: true, collection: HellosignCall.error_categories
  filter :created_at

  actions :all, :except => [:edit, :new]

  index do
    id_column
    column :api_end_point
    column :state
    column :call_type
    column :priority
    column :company
    actions
  end

  show do
    attributes_table do
      row :id
      row :api_end_point
      row :state
      row :call_type
      row :priority
      row :paperwork_request_id
      row :paperwork_template_ids
      row :hellosign_bulk_request_job_id
      row :user_ids
      row :bulk_paperwork_requests
      row :error_code
      row :error_name
      row :error_description
      row :error_category
      row :company
      row :job_requester
      row :created_at
      row :updated_at
    end
  end
end
