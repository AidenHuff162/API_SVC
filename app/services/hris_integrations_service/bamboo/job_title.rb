class HrisIntegrationsService::Bamboo::JobTitle
  attr_reader :company

  delegate :fetch, :create, to: :meta_list, prefix: :execute_meta_list

  def initialize(company)
    @company = company
  end

  def fetch
    meta_lists = execute_meta_list_fetch(['Job Title']).try(:first)['options'] rescue []
    meta_lists.select {|meta_list| meta_list['archived'].eql?("no") }.map{ |meta_list| meta_list['name']  }.uniq
  end

  def create(title)
    execute_meta_list_create(['Job Title'], "<options><option>#{title}</option></options>", 'Create Job title')
  end

  private

  def meta_list
    HrisIntegrationsService::Bamboo::MetaList.new company
  end
end
