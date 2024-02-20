class CustomFields::OnboardSectionManagement
	attr_accessor :collection, :company

	def initialize collection, company
		@collection = collection
		@company = company
	end

	def perform
    mergePrefrenceFieldsIntoCollection
		intializeCollectionSetions

		setSectionHeaderInfo(@collection, 'admin_header_info', 'admin')
		setSectionHeaderInfo(@collection, 'new_hire_header_info', 'new_hire')
		setSectionHeaderInfo(@collection, 'manager_header_info', 'manager')
		manageCollectionSections(@collection)
		@collection = renameKeys(@collection)
		return @collection
	end

	def intializeCollectionSetions
		@collection = @collection.group_by { |profile_field| profile_field[:collect_from] }
		@collection['admin'] = {} if @collection['admin'].blank?
		@collection['new_hire'] = {} if @collection['new_hire'].blank?
		@collection['manager'] = {} if @collection['manager'].blank?
	end

	def manageCollectionSections collection
    collection['admin'] = collection['admin'].group_by { |collect_from| collect_from[:custom_table_id] }
    collection['new_hire'] = collection['new_hire'].group_by { |collect_from| collect_from[:custom_table_id] }
    collection['manager'] = collection['manager'].group_by { |collect_from| collect_from[:custom_table_id] }
  end

  def setSectionHeaderInfo collection, header_name, section_name
    collection[header_name] = {}
    collection[header_name]['total'] = collection[section_name].count
    collection[header_name]['required'] = collection[section_name].select{|field| field[:required] == true || field[:enabled] == true}.count
  end

  def renameKeys collection
    collection.each do |section_name, section|
      section.keys.each do |key|
        custom_table_name =  @company.custom_tables.find_by(id: key).try(:name)
        section[custom_table_name] = section.delete key if custom_table_name.present?
        section['profile_fields'] = section.delete(key) if key == nil
      end
    end
  end

  def mergePrefrenceFieldsIntoCollection
  	preference_fields = @company.prefrences['default_fields'].select {
  		|preference_field| ['pn','bdy','abt','lin','twt','gh'].include?(preference_field['id']) }.each {
  			|profile_field| profile_field['custom_table_id'] = nil
  		}.map(&:with_indifferent_access)
  	@collection = (@collection + preference_fields).sort_by! { |profile_field| [profile_field[:position] ? 1 : 0, profile_field[:position]] }
  end
end
