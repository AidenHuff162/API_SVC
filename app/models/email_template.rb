class EmailTemplate < ApplicationRecord
  has_paper_trail
  belongs_to :company
  belongs_to :editor, class_name: 'User', foreign_key: :editor_id
  has_many :attachments, as: :entity, dependent: :destroy,
                        class_name: 'UploadedFile::Attachment'

  has_many :locations, -> (template) { where(id: template.meta['location_id']) }, through: :company
  has_many :teams, -> (template) { where(id: template.meta['team_id']) }, through: :company
  
  has_one :employment_field, through: :company
  has_many :employment_options, -> (template) { where(id: template.meta['employee_type']) }, through: :employment_field

  before_save :fix_line_breaks, if: :will_save_change_to_description?
  after_destroy :destroy_scheduled_emails

  validates :name, uniqueness: { scope: [:email_type, :company_id] }, on: [:create, :update] 

  scope :template_exist, -> (template_name, company_id){ where(name: template_name, is_temporary: false, company_id: company_id) }

  PRIORITIES_ORDERED = ['invitation', 'offboarding']

  def self.order_by_case
    ret = "CASE"
    PRIORITIES_ORDERED.each_with_index do |p, i|
      ret << " WHEN email_type = '#{p}' THEN #{i}"
    end
    ret << " END"
  end
  
  scope :order_by_priority, -> { order(order_by_case) }

  def fix_line_breaks
    self.description.gsub!('<p><br></p>','<br/>')
    self.description.gsub!('<p>&nbsp;</p>', '<br/>')
  end

  def get_cc(user)
    user ? token_service.replace_task_tokens(cc, user) : cc
  end

  def get_bcc(user)
    user ? token_service.replace_task_tokens(bcc, user) : bcc
  end

  def get_description(user)
    user ? token_service.replace_task_tokens(description, user).gsub(/\n/, '') : description
  end

  def get_subject(user)
    user ? token_service.replace_task_tokens(subject, user, nil, nil, nil, true).gsub(/\n/, '') : subject
  end

  def token_service
    @token_service ||= ReplaceTokensService.new
  end

  def get_editor
    sent_at =  self.updated_at || self.created_at
    if sent_at
      date = sent_at.strftime("%m/%d/%Y") rescue ''
      editor = self.editor.display_name rescue ''
    end
    {date: date, name: editor}
  end

  def get_locations
    self.meta.dig('location_id') == ['all'] ? ['all'] : locations
  end

  def departments
    self.meta.dig('team_id') == ['all'] ? ['all'] : teams
  end

  def status
    self.meta.dig('employee_type') == ['all'] ? ['all'] : employment_options
  end

  def location_ids
    meta['location_id'].map(&:to_s) if meta['location_id'] && meta['location_id']&.compact&.present? 
  end

  def department_ids
    meta['team_id'].map(&:to_s) if meta['team_id'] && meta['team_id']&.compact&.present?
  end

  def status_ids
    meta['employee_type'].map(&:to_s) if meta['employee_type'] && meta['employee_type']&.compact&.present?
  end

  def get_token_values(user)
    token_value_map = []

    if user
      tokens_copy = description
      while true
        start_idx = tokens_copy.index("<span class=\"token\"")
        break unless start_idx
        end_idx = tokens_copy.index("</span>", start_idx) + 7
        token_str = tokens_copy[start_idx ... end_idx]

        token_value_map.push [token_str, prepare_token(token_str, user)]
        tokens_copy = tokens_copy[end_idx .. -1]
        break if tokens_copy == ''
      end
    end

    token_value_map
  end

  def prepare_token(token_str, user)
    token_name = Nokogiri.HTML(token_str).text
    token = Nokogiri::HTML(token_str)
    xpath = "//*[@class='token']"
    node = token.xpath(xpath)[0]

    cf_id = node.attributes["data-name"].value
    cf_id = (cf_id && cf_id[/^-?\d+$/]) ? cf_id.to_i : nil
    token_service.fetch_token_value(token_name, user, nil, nil, nil, cf_id, false)
  end

  def map_email_type
    EMAIL_TYPES[email_type.to_sym] || email_type
  end

  private

  def destroy_scheduled_emails
    user_ids = company.users.ids
    pre_scheduled_emails = UserEmail.pre_scheduled_emails(user_ids)
    return unless pre_scheduled_emails

    template = ActionView::Base.full_sanitizer.sanitize(name)
    pre_scheduled_emails.where(template_name: template)&.destroy_all
  end
end
