namespace :documents do
  desc 'Update process type for both individual and packet documents'
  task :update_type , [:company_ids] => [:environment] do |task, args|
    company_ids = args[:company_ids].split(' ').map{ |s| s.to_i }

    company_ids.each do |company_id|
      company = Company.find_by(id: company_id)
      
      if company.present?
        create_process_types(company) if company.process_types.blank?
        excluded_types = ["Onboarding", "Offboarding",
                         "Relocation","Promotion", "Other"].map(&:to_json)

        company.paperwork_packets.where.not("meta ->'type'  @> any(array[?]::jsonb[])", excluded_types).find_each do |document_packet|
          update_process_type(document_packet)
        end
        puts "Updated paperwork_packets process type"

        company.document_upload_requests.where.not("meta ->'type'  @> any(array[?]::jsonb[])", excluded_types).find_each do |doc_upload_request|
          update_process_type(doc_upload_request)
        end
        puts "Updated document_upload_requests process type"

        company.documents.where.not("meta ->'type'  @> any(array[?]::jsonb[])", excluded_types).find_each do |document|
          update_process_type(document)
        end
        puts "Updated document_upload_requests process type"
      else
        puts "Company with id: #{company_id} not found!!!"
      end
    end
  end

  def create_process_types company
    ["Onboarding", "Offboarding", "Relocation", "Promotion", "Other"].each do |name|
      company.process_types.find_or_create_by(name: name, entity_type: "Workstream", is_default: true)
    end 
  end

  def update_process_type(document)
    current_process_type = document.meta["type"].downcase
    
    if ['welcome', 'new hire', 'onboarding', 'pre-boarding'].any? { |type| current_process_type.include?(type) }
      update_to_onboarding(document)
    elsif ['offboarding', 'exit', 'termination', 'disconnect'].any? { |type| current_process_type.include?(type) }
      update_to_offboarding(document)
    elsif ['relocation','relo', 'move'].any? { |type| current_process_type.include?(type) }
      update_to_relocation(document)
    elsif ['promotion', 'job family', 'merit'].any? { |type| current_process_type.include?(type) }
      update_to_promotion(document)
    else
      update_to_other(document)  
    end
  end
    
  def update_to_onboarding(document)
    document.meta['type'] = "Onboarding"
    document.save
  end

  def update_to_offboarding(document)
    document.meta['type'] = "Offboarding"
    document.save
  end

  def update_to_relocation(document)
    document.meta['type'] = "Relocation"
    document.save
  end

  def update_to_promotion(document)
    document.meta['type'] = "Promotion"
    document.save
  end

  def update_to_other(document)
    document.meta['type'] = "Other"
    document.save
  end
end