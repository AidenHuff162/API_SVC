class Location < ApplicationRecord
  acts_as_paranoid
  include GdprManagement

  has_paper_trail
  belongs_to :company, counter_cache: true
  belongs_to :owner, class_name: 'User'

  has_many :pending_hires, dependent: :nullify
  has_many :users, dependent: :nullify

  validates :name, :company, presence: true
  validates :name, uniqueness: { scope: [:company_id, :deleted_at] }
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)

  scope :get_name, -> (loc_id, company_id) { where(id: loc_id, company_id: company_id).take&.name }
  
  before_destroy :nullify_pending_hires
  after_create :update_pending_hires
  after_update :nullify_pendings, if: :saved_change_to_name?
  after_commit :update_location_in_company_org_chart, if: :saved_change_to_name?
  after_update :reindex_users, if: :saved_change_to_active?
  after_commit :clear_cache
  before_destroy { update_enforced_general_data_protection_regulation_on_location_deletion(self) if is_gdpr_imposed.present? }
  before_destroy :nullify_users_location

  def self.sync_adp_option_and_code(company, option, code, environment)
    return unless option.present? && code.present? && environment.present?

    option.strip!
    option_location = nil
    key = environment == 'US' ? 'adp_wfn_us_code_value' : 'adp_wfn_can_code_value'

    option_location = company.locations.where("name ILIKE ? AND #{key} = ?", option, code)&.take
    option_location = company.locations.where("name ILIKE ? OR #{key} = ?", option, code)&.take unless option_location
    option_location = company.locations.new unless option_location
    option_location.assign_attributes(name: option, "#{key}": code, active: true)
    option_location.save
    return option_location.id
  end

  def self.deactivate_adp_options(company, updated_option_ids, environment)
    key = environment == 'US' ? 'adp_wfn_us_code_value' : 'adp_wfn_can_code_value'
    company.locations.where.not('id IN (?)', updated_option_ids).where("#{key} IS NOT NULL").update_all(active: false)
  end

  def self.cached_location_serializer id
    Rails.cache.fetch(['locations', id], expires_in: 2.hours) do
      location = Location.find_by(id: id)
      ActiveModelSerializers::SerializableResource.new(location ,serializer: LocationSerializer::Short).as_json if location
    end
  end

  def get_cached_people_count
    Rails.cache.fetch([self.id, Date.today.to_s, 'location_members_count'], expires_in: 1.days) do
      UsersCollection.new(people: true, activated: true, location_id: self.id).results.count
    end
  end

  def self.expires_location_serializer id
    Rails.cache.delete(['locations', id])
    true
  end

  def self.expire_people_count id
    Location.expires_location_serializer id
    Rails.cache.delete([id, Date.today.to_s, 'location_members_count'])
    true
  end

  def self.update_locations_from_namely(locations=[], company, group_type)
    begin
      locations.each do |office_location|
        if office_location['title'].present?
          location = self.find_by("(name ILIKE ? OR namely_group_id = ?) AND company_id = ?", office_location['title'].strip, office_location['id'], company.id)
          if location.present?
            location.update(name: office_location['title'].strip, namely_group_type: group_type, namely_group_id: office_location['id'])
          else
            self.create(name: office_location['title'].strip, company_id: company.id, namely_group_type: group_type, namely_group_id: office_location['id'])
          end
        end
      end
    rescue Exception => exception
      puts "Update Location From Namely Exception: #{exception.inspect}"
    end
  end

  def get_object_name
    self.name
  end

  def nullify_users_location
    Location.expire_people_count self.id
    User.unscoped.where(location_id: self.id).update_all(location_id: nil)
  end

  def nullify_pending_hires
    PendingHire.with_deleted.where(location_id: self.id).update_all(location_id: nil)
  end

  def update_pending_hires
    self.company.pending_hires.each do |pending|
      next if pending.custom_fields.nil?
      loc = pending.custom_fields["location"]
      next if loc.nil?
      pending.update(location_id: self.id) if loc == self.name
      pending.user.update(location_id: self.id) if pending.user
    end
  end

  def nullify_pendings
    self.pending_hires.each do |pending|
      if pending.custom_fields.present? && pending.custom_fields["location"] != self.name
        pending.update(location_id: nil)
      end
    end
  end

  def reindex_users
    self.users.find_each do |user|
      User.trigger_algolia_worker(user, false)
    end
    true
  end

  def update_location_in_company_org_chart
    UpdateLocationTeamInCompanyOrgChartJob.perform_async(self.users.pluck(:id), self.company_id)
  end

  def clear_cache
    Location.expires_location_serializer self.id
    self.company.clear_cache_for_team_and_location
    true
  end

  def active_users
    self.users.where(state: "active").count
  end

  def inactive_users
    self.users.where(state: "inactive").count
  end

  def self.get_location_by_name(company, field_name)
    company.locations.find_by('name ILIKE ?', field_name)
  end

end
