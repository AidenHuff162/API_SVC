namespace :image_versions do
  desc 'Recreate profile_images of users'
  task recreate_users: :environment do
    User.all.each do |user|
      if user.profile_image.present?
        user.profile_image.file.recreate_versions!
        user.profile_image.save!
      end
    end
  end

  desc 'Recreate gallery_images of company'
  task recreate_company_gallery: :environment do
    Company.all.each do |comp|
      comp.gallery_images.each do |image|
        if image.present?
          image.file.recreate_versions!
          image.save!
        end
      end
    end
  end

  desc 'Recreate display_logo_image of company'
  task recreate_company_logo: :environment do
    Company.all.each do |comp|
      if comp.display_logo_image.present?
        comp.display_logo_image.file.recreate_versions!
        comp.display_logo_image.save!
      end
    end
  end

  desc 'Recreate landing_page_image of company'
  task recreate_company_landing: :environment do
    Company.all.each do |comp|
      if comp.landing_page_image.present?
        comp.landing_page_image.file.recreate_versions!
        comp.display_logo_image.save!
      end
    end
  end

  desc 'Recreate milestone_image of milestone'
  task recreate_milestones: :environment do
    Milestone.all.each do |mile|
      if mile.milestone_image.present?
        mile.milestone_image.file.recreate_versions!
        mile.milestone_image.save!
      end
    end
  end

  desc 'Execute all recreate images tasks'
  task recreate_all: [:recreate_users, :recreate_company_gallery, :recreate_company_logo, :recreate_company_landing, :recreate_milestones]
end
