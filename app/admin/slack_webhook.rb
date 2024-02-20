ActiveAdmin.register IntegrationErrorSlackWebhook, as: "Slack Webhooks" do
  
  
  menu label: "Slack Webhooks", parent: "Integrations"
  
  config.batch_actions = false
  permit_params :channel, :webhook_url, :status, :integration_type, :integration_name, :company_name, :configure_app

  form html: {id: "company", data: {parsley_validate: true} } do |f|
    f.inputs "Integration Error Slack Notification Credentials" do
    	f.input :channel, input_html: {required: ''}
    	f.input :webhook_url, input_html: {required: ''}
    	f.input :status, as: :select, collection: [["Active", 'active'], ["Inactive", 'inactive']]
      # f.input :integration_type, as: :select, collection: [["Human Resource Information System", 'human_resource_information_system'], ["Applicant Tracking System", 'applicant_tracking_system'], ["Issue and Project Tracker", 'issue_and_project_tracker']]
      f.input :integration_name, as: :select, collection: IntegrationLogging.integration_names
      f.input :event_type, as: :select, collection: [['Create', '0'], ['Update', '1'], ['Delete', '2']]
      f.input :company_name, as: :select, collection: Company.all_companies_alphabeticaly.pluck(:name)
      f.input :configure_app, as: :select, collection: [['Slack', 'slack'], ['Teams', 'teams']]
    end
    f.actions
  end
end
