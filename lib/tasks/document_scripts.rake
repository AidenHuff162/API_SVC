namespace :document_scripts do
	desc "fetch corrupted data"
	task :fetch_corrupted_data, [:company_id]  => [:environment] do |task, args|
		data = []
		companies = Company.where(id: args.company_id) if args.company_id
		
		companies ||= Company.where(account_type: ['production', 'implementation'])
		
		prs = PaperworkRequest.where('((paperwork_requests.state = ? AND co_signer_id IS NULL) OR (paperwork_requests.state = ? AND co_signer_id IS NOT NULL)) AND signed_document IS NULL', 'signed', 'all_signed').joins(:user).where(users: { company_id: companies.ids})  

		prs.each do |pr|
      data << {company_name: pr.user.company.name, user_id: pr.user_id, document_name: pr.document&.title}
		end

		puts data

		puts 'Task Completed'
  end

	task :find_and_fix_documents_data, [:company_id]  => [:environment] do |task, args|
		companies = Company.where(id: args.company_id) if args.company_id
		
		companies ||= Company.where(account_type: ['production', 'implementation'])

		prs = PaperworkRequest.where('(paperwork_requests.state = ?) OR (paperwork_requests.state = ? AND co_signer_id IS NOT NULL)', 'assigned', 'signed').joins(:user).where(users: { company_id: companies.ids, state: :active }).where.not(users: { current_stage: [:incomplete, :invited, :preboarding, :departed] })
		fixed = [] 
		errors = {} 
		prs.each do |pr| 
			begin 
				counter += 1 
				puts "Counter -- #{counter}" 
				sleep 61 if (counter % 90 == 0) 
				request = HelloSign.get_signature_request(signature_request_id: pr.hellosign_signature_request_id) 
				signers = request.data['signatures'] 
				if pr.assigned? 
					emp_signer_data = signers.select { |s| (s.data['order'] == 0 || s.data['signer_role'] == 'employee') && (s.data['status_code'] == 'signed') }.first 
					if emp_signer_data.present? 
						pr.update_column(:state, 'signed') 
						HellosignCall.upload_signed_document_to_firebase(pr.id, pr.user.company_id, pr.user_id) if (pr.co_signer_id.nil? && pr.signed_document.file.nil?) 
						fixed << pr.id 
					end 
				elsif pr.signed? && pr.co_signer_id.present? 
					co_signer_data = signers.select { |s| (s.data['order'] == 1 || (s.data['signer_role'] == 'representative' || s.data['signer_role'] == 'coworker')) && (s.data['status_code'] == 'signed') }.first 
					if co_signer_data.present? 
						pr.update_column(:state, 'all_signed') 
						HellosignCall.upload_signed_document_to_firebase(pr.id, pr.user.company_id, pr.user_id) if pr.signed_document.file.nil? 
						fixed << pr.id 
					end 
				end 
			rescue Exception => ex 
				errors[pr.id] = "#{ex.message}" 
			end  
		end;0 

		puts "----------\n"*4
		puts 'Fixed PaperworkRequest IDs:'
		puts fixed
		puts "----------\n"*4

		puts "----------\n"*4
		puts 'Errors:'
		puts errors
		puts "----------\n"*4


	end
end
