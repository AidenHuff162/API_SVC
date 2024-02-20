class Profile < ApplicationRecord
  acts_as_paranoid
  include FieldAuditing, UserStatisticManagement
  has_paper_trail
  belongs_to :user
  has_many :field_histories, as: :field_auditable
  after_commit :flush_cache

  attr_accessor :updating_integration

  AUDITING_FIELDS = ['about_you', 'facebook', 'twitter', 'linkedin', 'github'].freeze
  PROFILE_INFO_HASH = {'gh' => 'github', 'lin' => 'linkedin', 'twt' => 'twitter', 'abt' => 'about_you' }.freeze

  after_save :track_changed_fields, if: :auditing_fields_updated?

  def flush_cache
    Rails.cache.delete([self.user_id, 'cached_profile_about_you'])
    true
  end

  def get_profile_info(current_user, id)
    section = user.company.prefrences['default_fields'].select{|a| a['id'] == id}[0]['section'] rescue nil
    if section.present?
      if section == 'profile' || current_user.role == 'account_owner' || (PermissionService.new.fetch_accessable_custom_field_sections(user.company, current_user, user)).include?(CustomField.sections["#{section}"])
        self.send(PROFILE_INFO_HASH[id])
      end
    end
  end

  private

  def get_attribute_input_type attribute_name
    if attribute_name == 'about_you'
      'text'
    else
      'string'
    end
  end
end
