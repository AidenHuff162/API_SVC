ActiveAdmin.register CompanyEmail, as: "Emails" do
  config.batch_actions = false

  filter :company,collection: Company.all_companies_alphabeticaly
  filter :subject
  filter :sent_to, label: "To", as: :string
  filter :cc_email, label: "CC", as: :string
  filter :bcc_email, label: "BCC", as: :string
  filter :from
  filter :created_at

  index do
    selectable_column
    id_column
    column :subject
    column :to do |email|
      "#{email.to.join(", ").gsub(/^(.{50,}?).*$/m,'\1...') unless email.to.nil?}"
    end
    column :cc do |email|
      "#{email.cc.join(", ").gsub(/^(.{50,}?).*$/m,'\1...') unless email.cc.nil?}"
    end
    column :bcc do |email|
      "#{email.bcc.join(", ").gsub(/^(.{50,}?).*$/m,'\1...') unless email.bcc.nil?}"
    end
    column :from
    column :company
    column :sent_at
    actions
  end

  controller do

    def index
      current_admin_user.active_admin_loggings.create!(action: "View all Emails")
      emails = CompanyEmail.unscoped { super }
    end

    def show
      current_admin_user.active_admin_loggings.create!(action: "Viewed Email", company_email_id: params[:id])
      email = CompanyEmail.unscoped do
        super
        CompanyEmail.find_by(id: params[:id])
      end
      email
    end

    def destroy
      current_admin_user.active_admin_loggings.create!(action: "Deleted Email", company_email_id: params[:id])
      destroy!
    end

  end


  show do
    attributes_table do
      row :subject
      row "To:" do |email|
        "#{email.to.join(", ") unless email.to.nil?}"
      end
      row :from
      row "CC:" do |email|
        "#{email.cc.join(", ") unless email.cc.nil?}"
      end
      row "BCC:" do |email|
        "#{email.bcc.join(", ") unless email.bcc.nil?}"
      end
      row :sent_at
      row :attachment do |email|
        email.attachments.map do |attachment|
          link_to attachment.original_filename, attachment.file.download_url(attachment.original_filename), download: attachment.original_filename unless attachment.file.url.nil?
        end.join('<br />').html_safe
      end
      row :content do |email|
        iframe srcdoc: email.content, width:"100%", height:"830px", style: "display=block;width=100%;height=100%" do
        end
      end
    end
  end
end
