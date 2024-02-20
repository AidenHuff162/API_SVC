class DuplicateNameService < ApplicationService
  include ActionView::Helpers::SanitizeHelper

  def initialize(org_name, records)
    @org_name = org_name
    @records = records
  end

  def call
    @org_name = strip_tags(@org_name)
    duplicate_name = @org_name.insert(0, 'Copy of ')
    get_duplicate_name(duplicate_name, "%#{@org_name}%")
  end

  private 

  def get_duplicate_name(dup_name, pattern)
    existing_dups_copy_count = dup_name.scan(/Copy of /).size + 1
    existing_names = @records.where("name LIKE ?", pattern).pluck(:name)

    updated_count = existing_names.count{ |temp_name| temp_name.scan(/Copy of /).size == existing_dups_copy_count } + 1
    prev_name = dup_name.dup
    dup_name.insert(dup_name.length, " (#{updated_count})")

    while existing_names.include?(dup_name)
      dup_name = prev_name.dup
      updated_count += 1 
      dup_name.insert(dup_name.length, " (#{updated_count})")
    end
    dup_name 
  end
end

