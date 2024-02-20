module CompanySerializer
  class PreboardStory < ActiveModel::Serializer
    attributes :id, :name, :company_video, :bio, :about_section, :milestone_section, :values_section, :team_section, :onboard_class_section, :welcome_section,
      :company_value, :company_about

    has_many :milestones
    has_many :company_values
    has_many :gallery_images

  end
end
