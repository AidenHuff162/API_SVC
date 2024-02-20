require 'rails_helper'
require 'cancan/matchers'

describe UploadedFile do
	let(:company){ create(:company) }
	let(:sarah){ create(:sarah, company: company) }
	let(:nick){ create(:nick, company: company, start_date: Date.today - 1.year) }
	let(:peter){ create(:peter, company: company) }

  describe 'authorisation' do
  	context 'attachment belonging to same company' do
	  	let(:uploaded_file){ create(:uploaded_file, company_id: company.id, type: 'UploadedFile::Attachment') }
	  	subject(:ability) { Ability.new(sarah) }
	  	it{ should be_able_to(:manage, uploaded_file) }
	  	subject(:ability){ Ability.new(nick) }
	  	it{ should be_able_to(:manage, uploaded_file) }
	  	subject(:ability) { Ability.new(peter) }
	  	it{ should be_able_to(:manage, uploaded_file) }
  	end
  	context 'attachment belonging to other company' do
  		let(:second_company){ create(:company, subdomain: 'snickerbar')}
  		let(:other_company_file){ create(:uploaded_file, company_id: second_company.id, type: 'UploadedFile::Attachment')}
  		subject(:ability) { Ability.new(sarah) }
	  	it{ should_not be_able_to(:manage, other_company_file) }
	  	subject(:ability){ Ability.new(nick) }
	  	it{ should_not be_able_to(:manage, other_company_file) }
	  	subject(:ability) { Ability.new(peter) }
	  	it{ should_not be_able_to(:manage, other_company_file) }
  	end
  	context 'attachment having entity type' do
  		let(:workstream){ create(:workstream, company: company) }
  		let(:task){ create(:task, workstream: workstream) }
  		let(:uploaded_file){ create(:uploaded_file, company_id: company.id, entity_id: task.id, entity_type: 'Task', type: 'UploadedFile::Attachment') }
  		subject(:ability) { Ability.new(sarah) }
  		it{should be_able_to(:manage, uploaded_file)}
  		subject(:ability) { Ability.new(peter) }
  		it{should be_able_to(:manage, uploaded_file)}
  		context 'employee trying to manage attachment' do
  			context 'entity is not pto request' do
  				subject(:ability) { Ability.new(nick) }
  				it{should_not be_able_to(:manage, uploaded_file)}
  			end
  			context 'entity is not pto request but the user themself' do
  				let(:new_attachment){ create(:uploaded_file, company_id: company.id, type: 'UploadedFile::ProfileImage', entity_id: nick.id, entity_type: 'User')}
  				it{should be_able_to(:manage, new_attachment) }
  			end
  			context 'entity is pto request' do
  				let(:new_user){ create(:nick, email: 'testmail12@mail.com', personal_email: 'teasd12@mail.com', company: company, start_date: Date.today - 1.year) }
          before {User.current = new_user}
  				let(:pto_policy){ create(:default_pto_policy, manager_approval: false, company: company, tracking_unit: 'hourly_policy') }
  				subject(:ability) { Ability.new(nick) }
  				context 'should be able to manage attachment' do
  					let!(:assigned_pto_policy){ create(:assigned_pto_policy, pto_policy: pto_policy, user: nick,  balance: 20, carryover_balance: 20) }
	  				let(:pto_request) { create(:pto_request, user: nick, pto_policy: pto_policy, partial_day_included: false,
	  				 status: 0, begin_date: company.time.to_date,
	  				 end_date: ( company.time.to_date + 2.days), 
	  				 balance_hours: 24) }
  					let(:new_attachment){ create(:uploaded_file, company_id: company.id, type: 'UploadedFile::Attachment', entity_id: pto_request.id, entity_type: 'PtoRequest' )}
  					it{ should be_able_to(:manage, new_attachment) }	
  				end
  				context 'should not be able to manage if pto requests belongs to another user' do
	  				let!(:assigned_pto_policy){ create(:assigned_pto_policy, pto_policy: pto_policy, user: new_user, balance: 20, carryover_balance: 20) }
	  				let(:pto_request) { create(:pto_request, user: new_user, pto_policy: pto_policy, partial_day_included: false,
	  				 status: 0, begin_date: company.time.to_date,
	  				 end_date: ( company.time.to_date + 2.days), 
	  				 balance_hours: 24) }
	  				let(:new_attachment){ create(:uploaded_file, company_id: company.id, type: 'UploadedFile::Attachment', entity_id: pto_request.id, entity_type: 'PtoRequest' )}
  					it{ should_not be_able_to(:manage, new_attachment) }
  				end
  			end
  		end
  	end
  end

  describe 'Methods' do
    describe '#clear_file' do
      let(:uploaded_file) { create(:profile_image, :for_sarah) }

      it 'clears uploaded file' do
        allow_any_instance_of(ProfileImageUploader).to \
          receive(:secure_token).and_return('testtoken')
        expect(uploaded_file.file.url).to match(/testtoken/)

        uploaded_file.clear_file

        expect(uploaded_file.file).to be_blank
      end
    end
  end
end
