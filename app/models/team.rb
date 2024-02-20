class Team < ApplicationRecord
  has_paper_trail
  belongs_to :company, counter_cache: true
  belongs_to :owner, class_name: 'User'

  has_many :users, dependent: :nullify

  validates :name, :company, presence: true
  validates :name, uniqueness: { scope: :company_id }
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)

  scope :get_name, -> (team_id, company_id) { where(id: team_id, company_id: company_id).take&.name }

  before_destroy :nullify_users_team
  after_commit :clear_cache
  after_commit :update_team_in_company_org_chart, if: :saved_change_to_name?

  def self.sync_adp_option_and_code(company, option, code, environment, company_code = 'default')
    return unless option.present? && code.present? && environment.present?

    if environment == 'US'
      team_option = fetch_team_option(option, company.id)
      team_option.update(name: option, adp_wfn_us_code_value: build_hash_value(team_option, code, environment, company_code))
    elsif environment == 'CAN'
      team_option = fetch_team_option(option, company.id)
      team_option.update(name: option, adp_wfn_can_code_value: build_hash_value(team_option, code, environment, company_code))
    end
  end

  def self.update_departments_from_namely(departments=[], company, group_type)
    begin
      departments.each do |department|
        if department['title'].present?
          team = self.find_by("(name ILIKE ? OR namely_group_id = ?) AND company_id = ?", department['title'].strip, department['id'], company.id)
          if team.present?
            team.update(name: department['title'].strip, namely_group_type: group_type, namely_group_id: department['id'])
          else
            self.create(name: department['title'].strip, company_id: company.id, namely_group_type: group_type, namely_group_id: department['id'])
          end
        end
      end
    rescue Exception => exception
      puts "Update Department From Namely Exception: #{exception.inspect}"
    end
  end

  def self.cached_team_serializer id    
    Rails.cache.fetch(['teams', id], expires_in: 2.hours) do
      team = Team.find_by(id: id)
      ActiveModelSerializers::SerializableResource.new(team ,serializer: TeamSerializer::Short).as_json if team
    end
  end

  def get_cached_people_count
    Rails.cache.fetch([self.id, Date.today.to_s, 'team_members_count'], expires_in: 1.days) do
      UsersCollection.new(people: true, activated: true, team_id: self.id).results.count
    end
  end

  def self.expires_team_serializer id
    Rails.cache.delete(['teams', id])
    true
  end

  def self.expire_people_count id
    self.expires_team_serializer id
    Rails.cache.delete([id, Date.today.to_s, 'team_members_count'])
    true
  end

  def get_object_name
    self.name
  end

  def nullify_users_team   
    Team.expire_people_count self.id
    if self.company.users
      self.company.users.unscoped.where(team_id: self.id).update_all(team_id: nil)
    end
  end

  def active_users    
    self.users.where(state: "active").count
  end

  def inactive_users
    self.users.where(state: "inactive").count
  end

  def self.get_team_by_name(company, field_name)
    company.teams.find_by('name ILIKE ?', field_name)
  end

  def get_adp_wfn_code_value(enviornment, code_value)
    adp_wfn_code_value = enviornment == 'US' ? self.adp_wfn_us_code_value : self.adp_wfn_can_code_value
    return nil if adp_wfn_code_value.blank?
    
    does_adp_wfn_code_exists?(adp_wfn_code_value, code_value)
  end

  def does_adp_wfn_code_exists?(adp_wfn_code_value, code_value)
    JSON.parse(adp_wfn_code_value).to_a.count { |code| code[1] == code_value }.positive? ? self : nil
  end

  private

  def clear_cache
    Team.expires_team_serializer self.id
    self.company.clear_cache_for_team_and_location
    true
  end

  def update_team_in_company_org_chart
    UpdateLocationTeamInCompanyOrgChartJob.perform_async(self.users.pluck(:id), self.company_id)
  end

  def self.fetch_team_option(option, company_id); Team.where('company_id = (?) AND name ILIKE (?) ', company_id, option).first_or_create(name: option, company_id: company_id) end
  def self.build_hash_value(option, code, environment, company_code)
    value = environment == 'US' ? option.adp_wfn_us_code_value : option.adp_wfn_can_code_value
    json_hash = value ? JSON.parse(value) : {} rescue {}
    json_hash.merge!({"#{company_code}": code}).to_json
  end
end
