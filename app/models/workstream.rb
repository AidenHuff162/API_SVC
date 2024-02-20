class Workstream < ApplicationRecord
  acts_as_paranoid
  has_paper_trail

  after_destroy :reposition_workstream
  # before_destroy :nullifying_associated_data
  belongs_to :company
  has_many :tasks, dependent: :destroy
  belongs_to :updated_by, class_name: 'User', foreign_key: :updated_by_id
  validates :company, :name, presence: true
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)
  belongs_to :process_type

  default_scope { order(position: :asc) }

  def reposition_workstream
    workstreams = self.company.workstreams.order(:position) rescue nil
    workstreams.each_with_index do |w,index|
      w.update_column(:position, index+1)
    end if workstreams
  end
  
  # def nullifying_associated_data
  #   Task.with_deleted.where(workstream_id: self.id).update_all(workstream_id: nil)
  # end
end
