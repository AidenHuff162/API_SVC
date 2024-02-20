class HrisIntegrationsService::Bamboo::Location
  attr_reader :company

  delegate :fetch, :create, to: :meta_list, prefix: :execute_meta_list

  def initialize(company)
    @company = company
  end

  def fetch
    return [] unless !company.location_mapping_key.blank?

    meta_lists = execute_meta_list_fetch([company.location_mapping_key]).try(:first)['options'] rescue []
    meta_lists.select {|meta_list| meta_list['archived'].eql?("no") }.map{ |meta_list| meta_list['name']  }
  end

  private

  def meta_list
    HrisIntegrationsService::Bamboo::MetaList.new company
  end
end
