ActiveAdmin.register IntegrationInstance, as: "ADP Keys" do

  menu label: "ADP Keys", parent: "Integrations" 
  config.batch_actions = false
  permit_params :company_id, :company_code, :environment

  filter :company, collection: proc { Company.all_companies_alphabeticaly }

  controller do
    def scoped_collection
      end_of_association_chain.where(api_identifier: ['adp_wfn_us', 'adp_wfn_can'])
    end

    def create
      Integrations::AdpWorkforceNow::AquireCredentials.new(params[:integration_instance][:company_code], params[:integration_instance][:company_id], params[:integration_instance][:environment]).fetch_and_save_ids
      redirect_to action: "index"
    end
  end

  index do
    column :api_identifier
    column :company
  end

  form html: {id: "adp_form", data: {parsley_validate: true} } do |f|
    f.inputs "Aquire ADP creentials" do
      f.input :company_code, label: 'Organization ID', input_html: {required: ''}
      f.input :environment, label: 'ADP Environment', input_html: {required: ''}, as: :select, collection: [["United Stated", 'US'], ["Canada", 'CAN']]
      f.input :company_id, label: "Company", input_html: {required: ''}, as: :select, collection: Company.where(deleted_at: nil).all_companies_alphabeticaly
    end
    f.actions
  end
end
