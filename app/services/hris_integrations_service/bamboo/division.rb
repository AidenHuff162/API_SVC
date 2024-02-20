class HrisIntegrationsService::Bamboo::Division
  attr_reader :company, :division

  delegate :fetch, :create, to: :meta_list, prefix: :execute_meta_list

  def initialize(company, division)
    @company = company
    @division = division
  end

  def fetch
    return [] unless !division.mapping_key.blank?

    meta_lists = execute_meta_list_fetch([division.mapping_key]).try(:first)['options'] rescue []
    meta_lists.select {|meta_list| meta_list['archived'].eql?("no") }.map{ |meta_list| meta_list['name']  }.uniq
  end

  private

  def meta_list
    HrisIntegrationsService::Bamboo::MetaList.new company
  end
end
