require 'rails_helper'

RSpec.describe Api::V1::UploadedFilesController, type: :controller do
	let(:company) { create(:company) }
	let(:sarah) { create(:sarah, company: company) }
	let(:peter){ create(:peter, company: company) }
	let(:nick){ create(:nick, company: company) }

	before do
		allow(controller).to receive(:current_company).and_return(company)
		allow(controller).to receive(:current_user).and_return(sarah)
	end

	describe 'create' do
		context 'unauthenticated user' do
			before do
				allow(controller).to receive(:current_user).and_return(nil)
			end
			it 'should not upload landing page image' do
				post :create, params: {company_id: company.id, type: 'landing_page_image', file: Rack::Test::UploadedFile.new(File.join(Rails.root, 'spec', 'factories', 'uploads', 'companies', 'display_logo_image', 'rocketship.png'))}, format: :json
				expect(response.status).to eq(401)
			end
			it 'should not upload display logo image' do
				post :create,  params: {company_id: company.id, type: 'display_logo_image', file: Rack::Test::UploadedFile.new(File.join(Rails.root, 'spec', 'factories', 'uploads', 'companies', 'display_logo_image', 'rocketship.png'))}, format: :json
				expect(response.status).to eq(401)
			end
			it 'should not upload gallery image' do
				post :create,  params: {company_id: company.id, type: 'gallery_image', file: Rack::Test::UploadedFile.new(File.join(Rails.root, 'spec', 'factories', 'uploads', 'companies', 'display_logo_image', 'rocketship.png'))}, format: :json
				expect(response.status).to eq(401)
			end
			it 'should not upload milestone image' do
				post :create,  params: {company_id: company.id, type: 'milestone_image', file: Rack::Test::UploadedFile.new(File.join(Rails.root, 'spec', 'factories', 'uploads', 'companies', 'display_logo_image', 'rocketship.png'))}, format: :json
				expect(response.status).to eq(401)
			end
			it 'should not upload company value image' do
				post :create,  params: {company_id: company.id, type: 'company_value_image', file: Rack::Test::UploadedFile.new(File.join(Rails.root, 'spec', 'factories', 'uploads', 'companies', 'display_logo_image', 'rocketship.png'))}, format: :json
				expect(response.status).to eq(401)
			end
			it 'should not create document upload request' do
				post :create,  params: {company_id: company.id, type: 'document_upload_request', file: Rack::Test::UploadedFile.new(File.join(Rails.root, 'spec', 'factories', 'uploads', 'documents', 'doc.pdf'))}, format: :json
				expect(response.status).to eq(401)
			end
			it 'should not upload the attachment' do
				post :create,  params: {company_id: company.id, type: 'attachment', file: 'pto_upload.csv'}, format: :json
				expect(response.status).to eq(401)
			end
			it 'should not upload the profile_image' do
				post :create,  params: {company_id: company.id, type: 'profile_image', file: 'adasdasdpoew12ewdasdsadsad.jpg'}, format: :json
				expect(response.status).to eq(401)
			end
			it 'should not upload the document' do
				post :create,  params: {company_id: company.id, type: 'document', file: 'doc.pdf'}, format: :json
				expect(response.status).to eq(401)
			end
		end
		context 'authenticated user' do
			before do
				allow(controller).to receive(:current_user).and_return(sarah)
			end
			it 'should upload landing page image' do
				post :create,  params: {company_id: company.id, type: 'landing_page_image', file: Rack::Test::UploadedFile.new(File.join(Rails.root, 'spec', 'factories', 'uploads', 'companies', 'display_logo_image', 'rocketship.png'))}, format: :json
				expect(response.status).to eq(201)
			end
			it 'should upload display logo image' do
				post :create,  params: {company_id: company.id, type: 'display_logo_image', file: Rack::Test::UploadedFile.new(File.join(Rails.root, 'spec', 'factories', 'uploads', 'companies', 'display_logo_image', 'rocketship.png'))}, format: :json
				expect(response.status).to eq(201)
			end
			it 'should upload gallery image' do
				post :create,  params: {company_id: company.id, type: 'gallery_image', file: Rack::Test::UploadedFile.new(File.join(Rails.root, 'spec', 'factories', 'uploads', 'companies', 'display_logo_image', 'rocketship.png'))}, format: :json
				expect(response.status).to eq(201)
			end
			it 'should upload milestone image' do
				post :create,  params: {company_id: company.id, type: 'milestone_image', file: Rack::Test::UploadedFile.new(File.join(Rails.root, 'spec', 'factories', 'uploads', 'companies', 'display_logo_image', 'rocketship.png'))}, format: :json
				expect(response.status).to eq(201)
			end
			it 'should upload company value image' do
				post :create,  params: {company_id: company.id, type: 'company_value_image', file: Rack::Test::UploadedFile.new(File.join(Rails.root, 'spec', 'factories', 'uploads', 'companies', 'display_logo_image', 'rocketship.png'))}, format: :json
				expect(response.status).to eq(201)
			end
			it 'should create document upload request' do
				post :create,  params: {company_id: company.id, type: 'document_upload_request', file: Rack::Test::UploadedFile.new(File.join(Rails.root, 'spec', 'factories', 'uploads', 'documents', 'doc.pdf'))}, format: :json
				expect(response.status).to eq(201)
			end
			it 'should upload the attachment' do
				post :create,  params: {company_id: company.id, type: 'attachment', file: Rack::Test::UploadedFile.new( File.join(Rails.root, 'spec', 'factories', 'uploads', 'documents', 'pto_upload.csv'))}, format: :json
				expect(response.status).to eq(201)
			end
			it 'should upload the profile image' do
				post :create,  params: {company_id: company.id, type: 'profile_image', file: Rack::Test::UploadedFile.new(File.join(Rails.root, 'spec', 'factories', 'uploads', 'users', 'profile_image', 'nick.jpg'))}, format: :json
				expect(response.status).to eq(201)
			end
			it 'should upload the document' do
				post :create,  params: {company_id: company.id, type: 'document', file: 'doc.pdf'}, format: :json
				expect(response.status).to eq(201)
			end
		end
	end

	describe 'Update' do
		context 'unauthenticated user' do
			let(:attachment){ create(:uploaded_file, company_id: company.id, type: 'UploadedFile::Attachment') }
			before do
				allow(controller).to receive(:current_user).and_return(nil)
			end
			it 'should not update the attachment' do
				post :update,  params: {id: attachment.id, entity_type: 'User'}, format: :json
				expect(response.status).to eq(401)
			end
		end
		context 'authenticated user' do
			let(:attachment){ create(:uploaded_file, company_id: company.id, type: 'UploadedFile::Attachment') }
			before do
				allow(controller).to receive(:current_user).and_return(sarah)
			end
			it 'should update the attachment' do
				post :update,  params: {id: attachment.id, type: 'attachment', entity_type: 'User'}, format: :json
				expect(JSON.parse(response.body)['entity_type']).to eq('User')
			end
		end
	end

	describe 'scan_file' do
		context 'unauthenticated user' do
			before do
				allow(controller).to receive(:current_user).and_return(nil)
			end
			it 'should not scan the attachment' do
				post :scan_file,  params: {file: Rack::Test::UploadedFile.new( File.join(Rails.root, 'spec', 'factories', 'uploads', 'documents', 'pto_upload.csv')), type: 'attachment'}, format: :json
				expect(response.status).to eq(401)
			end
		end
		context 'authenticated user' do
			before do
				allow(controller).to receive(:current_user).and_return(sarah)
			end
			it 'should scan the attachment' do
				post :scan_file,  params: {file: Rack::Test::UploadedFile.new( File.join(Rails.root, 'spec', 'factories', 'uploads', 'documents', 'pto_upload.csv')), type: 'attachment'}, format: :json
				expect(response.status).to eq(422)
			end
		end
	end

	describe '#destroy' do
		let(:attachment){ create(:uploaded_file, company_id: company.id, type: 'UploadedFile::Attachment') }
		context 'being accessed by unauthenticated user' do
			before do
				allow(controller).to receive(:current_user).and_return(nil)
			end
			it 'should return 401 response' do
				delete :destroy, params: { id: attachment.id }, format: :json
				expect(response.status).to eq(401)
			end
		end
		context 'being accessed by authenticated user' do
			context 'and authenticated user is sarah' do
				it 'should delete the attachment' do
					delete :destroy, params: { id: attachment.id }, format: :json
					expect(response.status).to eq(204)
				end
			end
			context 'and user is peter' do
				before do
					allow(controller).to receive(:current_user).and_return(peter)
				end
				it 'should delete the attachment' do
					delete :destroy, params: { id: attachment.id }, format: :json
					expect(response.status).to eq(204)
				end
			end
			context 'and user is nick' do
				before {User.current = nick}
				let(:pto_policy){ create(:default_pto_policy, manager_approval: false, company: company, tracking_unit: 'hourly_policy') }
				let!(:assigned_pto_policy){ create(:assigned_pto_policy, pto_policy: pto_policy, user: nick, balance: 20, carryover_balance: 20) }
				let(:pto_request) { create(:pto_request, user: nick, pto_policy: pto_policy, partial_day_included: false,
					status: 0, begin_date: company.time.to_date + 365.days,
					end_date: ( company.time.to_date + 365.days),
					balance_hours: 24) }
				let(:pto_attachment){ create(:uploaded_file, company_id: company.id, entity_id: pto_request.id, entity_type: 'PtoRequest', type: 'UploadedFile::Attachment')}
				context 'attachment entity type is PTO' do
					before do
					  allow(controller).to receive(:current_user).and_return(nick)
					end
					context 'pto request belongs to nick' do
						it 'should delete the attachment' do
							delete :destroy, params: { id: pto_attachment.id }, format: :json
							expect(response.status).to eq(204)
						end
					end
				end
				context 'another employee attempting to remove attachment of nick' do
					let(:simon){ create(:nick, company: company, email: 'woody@mail.com', personal_email: 'wood@mail.com') }
					before do
					  allow(controller).to receive(:current_user).and_return(simon)
					end
					it 'should not allow to delete attachment' do
						delete :destroy, params: { id: pto_attachment.id }, format: :json
						expect(response.status).to eq(403)
					end
				end
				context 'attachment entity is not pto_request' do
					let(:workstream){ create(:workstream, company: company) }
					let(:task){ create(:task, workstream: workstream) }
					let(:pto_attachment){ create(:uploaded_file, company_id: company.id, entity_id: task.id, entity_type: 'Task', type: 'UploadedFile::Attachment')}
					before do
					  allow(controller).to receive(:current_user).and_return(nick)
					end
					it 'should not allow to delete attachment' do
						delete :destroy, params: { id: pto_attachment.id }, format: :json
						expect(response.status).to eq(403)
					end
				end
			end
		end
	end
	describe '#destroy_all_unused' do
		let(:uploaded_file_1){ create(:uploaded_file, company_id: company.id, type: 'UploadedFile::Attachment') }
		let(:uploaded_file_2){ create(:uploaded_file, company_id: company.id, type: 'UploadedFile::Attachment') }
		context 'accessed by unauthenticated user' do
			before do
			  allow(controller).to receive(:current_user).and_return(nil)
			end
			it 'should return 401' do
				post :destroy_all_unused, params: { ids: [uploaded_file_1.id, uploaded_file_2.id] }, format: :json
				expect(response.status).to eq(401)
			end
		end
		context 'accessed by authenticated user' do
			it 'should remove the mentioned attachments' do
				file1_id = uploaded_file_1.id
				file2_id = uploaded_file_2.id
				post :destroy_all_unused, params: { ids: [file1_id, file2_id] }, format: :json
				expect(response.status).to eq(201)
				expect(UploadedFile.find_by_id(file1_id)).to eq(nil)
				expect(UploadedFile.find_by_id(file2_id)).to eq(nil)
			end
		end
	end
end
