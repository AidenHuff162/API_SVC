class Report < ApplicationRecord
  acts_as_paranoid
  attr_accessor :report_creator_id
  include UserRoleManagement

  has_paper_trail
  has_many :custom_field_reports, dependent: :destroy
  belongs_to :users, class_name: "User", foreign_key: "user_id"
  belongs_to :company
  belongs_to :sftp
  validate :start_date_is_less_than_end_date

  after_create { |action| action.assign_default_user_role_ids_to_report(self) }
  before_save :maintain_user_roles_uniqueness
  before_save :manage_report_sftp

  enum report_type: { user: 0, time_off: 1, workflow: 2, document: 3, track_user_change: 4, point_in_time: 5, survey: 6 }


  FIELDS_MAPPING = {
    "fn"  => "first_name",
    "ln"  => "last_name",
    "pn"  => "preferred_name",
    "ce"  => "company_email",
    "pe"  => "personal_email",
    "dpt" => "department",
    "sd"  => "start_date",
    "loc" => "location",
    "ltw" => "last_day_worked",
    "jt"  => "job_title",
    "es"  => "employement_status",
    "td"  => "termination_date",
    "tt"  =>"termination_type",
    "efr" => "eligible_for_rehire",
    "man" => "manager",
    "ap"  => "access_permission",
    "abt" => "about_you",
    "lin" => "linkedin",
    "twt" => "twitter",
    "ui" => "user_id",
    "gh"  => "github",
    "bdy" => "buddy",
    "jbt" => "job_tier",
    "st"  => "status",
    "acc" => "accrued",
    "bb" => "beginning balance",
    "use" => "used",
    "sch" => "scheduled",
    "adj" => "adjustments",
    "eb" => "ending balance",
    "pi" => "paylocity id",
    "mge" => "manager_email",
    "la" => "last_active",
    "lsi" => "last_sign_in_at",
    "stg" => "stage",
    "tot" => "time_off_type",
    "pln" => "policy_names",
    "los" => "length_of_service",
    "roll" => "rollover_balance"
  }.freeze

  def get_report_name_with_time
    creation_time = DateTime.now.utc.in_time_zone(self.company.time_zone)
    unless self.name == "default"
      "#{self.name} (#{creation_time.strftime("%m/%d/%Y")}, #{creation_time.strftime("%I:%M%p")})"
    else
      "#{self.company.name} - Headcount Report (#{creation_time.strftime("%m/%d/%Y")}, #{creation_time.strftime("%I:%M%p")})"
    end
  end

  def self.default_report(company, params = nil)
    report = Report.new
    date_filter = nil
    date_filter = params["date_filter"]
    report_filters = JSON.parse(params['filters'])
    option_ids = []
    team_ids = []
    location_ids = []
    if report_filters.present?
      report_filters['mcq'].try(:each) do |k,v|
        option_ids.push v
      end
      report_filters['employment_status'].try(:each) do |k,v|
        option_ids.push v
      end
      report_filters['Departments'].try(:each) do |k,v|
        team_ids.push v
      end
      report_filters['Locations'].try(:each) do |k,v|
        location_ids.push v
      end
    end
    option_ids = option_ids.reject { |ids| ids.empty? }
    end_date = date_filter.to_date.strftime("%m/%d/%Y") rescue nil
    report.permanent_fields = [
      { "id" => "ui", "position" => 0 },
      { "id" => "sd", "position" => 1 },
      { "id" => "fn", "position" => 2 },
      { "id" => "pn", "position" => 3 },
      { "id" => "ln", "position" => 4 },
      { "id" => "jt", "position" => 5 },
      { "id" => "ce", "position" => 6 },
      { "id" => "dpt", "position" => 7 },
      { "id" => "loc", "position" => 8 }
    ]
    report.meta = {
      "team_id" => team_ids.first,
      "location_id" => location_ids.first,
      "filter_by" => "selected_date",
      "sort_by" => "start_date_desc",
      "employee_type" => "all_employee_status",
      "mcq_filters" => option_ids,
      "date_range_type" => 4,
      "start_date" => nil,
      "end_date" => end_date,
      "is_default" => true
    }
    report.name = "default"
    report.company_id = company.id
    report
  end

  def self.turnover_report(company, params = nil)
    report = Report.new
    date_filter = nil
    date_filter = params["date_filter"]
    report_filters = JSON.parse(params['filters'])
    option_ids = []
    team_ids = []
    location_ids = []
    termination_types = []
    if report_filters.present?
      report_filters['mcq'].try(:each) do |k,v|
        option_ids.push v
      end
      report_filters['employment_status'].try(:each) do |k,v|
        option_ids.push v
      end
      report_filters['Departments'].try(:each) do |k,v|
        team_ids.push v
      end
      report_filters['Locations'].try(:each) do |k,v|
        location_ids.push v
      end    
      report_filters['termination_type'].try(:each) do |k,v|
        termination_types.push v
      end

    end
    option_ids = option_ids.reject { |ids| ids.empty? }
    start_date = ((date_filter.to_date - 11.months).beginning_of_month).strftime("%m/%d/%Y") rescue nil
    end_date = date_filter.to_date.strftime("%m/%d/%Y") rescue nil
    report.permanent_fields = [
      { "id" => "ui", "position" => 0 },
      { "id" => "sd", "position" => 1 },
      { "id" => "td", "position" => 2 },
      { "id" => "ltw", "position" => 3 },
      { "id" => "fn", "position" => 4 },
      { "id" => "pn", "position" => 5 },
      { "id" => "ln", "position" => 6 },
      { "id" => "jt", "position" => 7 },
      { "id" => "ce", "position" => 8 },
      { "id" => "dpt", "position" => 9 },
      { "id" => "loc", "position" => 10 },
      { "id" => "tt", "position" => 11 },
      { "id" => "los", "position" => 12 },
      { "id" => "efr", "position" => 13 }
    ]
    report.meta = {
      "team_id" => team_ids.first,
      "location_id" => location_ids.first,
      "sort_by" => "termination_date_desc",
      "employee_type" => "all_employee_status",
      "mcq_filters" => option_ids,
      "date_range_type" => 4,
      "filter_by" => "turnover_departed_users",
      "start_date" => start_date,
      "end_date" => end_date,
      "is_default" => true,
      'termination_type_filter' => termination_types.first
    }
    report.name = "turnover"
    report.company_id = company.id
    report
  end

  private

  def maintain_user_roles_uniqueness
    self.user_role_ids = self.user_role_ids.to_a.uniq
  end

  def start_date_is_less_than_end_date
    self.errors.add(:policy, I18n.t('errors.invalid_date').to_s) if self.meta.present? && self.meta['start_date'].present? && self.meta['end_date'].present? && Date.strptime(self.meta['start_date'],'%m/%d/%Y') > Date.strptime(self.meta['end_date'],'%m/%d/%Y')
  end

   def manage_report_sftp
   if self.meta['recipient_type'] != 'sftp'
      self.sftp = nil
    end
  end
end
