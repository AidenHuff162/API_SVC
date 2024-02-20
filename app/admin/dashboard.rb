ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc{ I18n.t("active_admin.dashboard") }

  content title: proc{ I18n.t("active_admin.dashboard") } do
    columns do
      column do
        panel I18n.t('active_admin.recent.users') do
          ul do
            User.joins(:company).where(companies: {deleted_at: nil}).last(20).reverse.map do |user|
              li link_to(user.first_name + ' ' + user.last_name, admin_user_path(user))
            end
          end
        end
      end

      column do
        panel I18n.t('active_admin.recent.companies') do
          ul do
            Company.where(deleted_at: nil).last(20).reverse.map do |company|
              li link_to(company.name, admin_company_path(company))
            end
          end
        end
      end
      
      column do
        panel I18n.t('active_admin.recent.admin_users') do
          ul do
            AdminUser.last(20).reverse.map do |user|
              li link_to(user.email, admin_admin_user_path(user))
            end
          end
        end
      end

    end
  end
end
