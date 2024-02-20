require 'rails_helper'

RSpec.describe PendingHire, type: :model do

	let(:company) { create(:company_with_team_and_location, subdomain: 'pending-hire') }
	let(:user) { create(:user, company: company) }
 	let(:incomplete_user) { create(:user, company: company, current_stage: User.current_stages[:incomplete]) }
  let(:pending_hire) { create(:pending_hire, personal_email: 'pending_hire@testtest.com') }

	describe 'Associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:location) }
    it { is_expected.to belong_to(:team) }
    it { is_expected.to belong_to(:manager).class_name('User') }
  end

  describe 'column specifications' do
  	it { is_expected.to have_db_column(:first_name).of_type(:string) }
  	it { is_expected.to have_db_column(:last_name).of_type(:string) }
  	it { is_expected.to have_db_column(:title).of_type(:string) }
  	it { is_expected.to have_db_column(:personal_email).of_type(:string) }
  	it { is_expected.to have_db_column(:phone_number).of_type(:string) }
  	it { is_expected.to have_db_column(:manager).of_type(:string) }
  	it { is_expected.to have_db_column(:start_date).of_type(:string) }
  	it { is_expected.to have_db_column(:employee_type).of_type(:string) }
  	it { is_expected.to have_db_column(:address_line_1).of_type(:string) }
  	it { is_expected.to have_db_column(:address_line_2).of_type(:string) }
  	it { is_expected.to have_db_column(:city).of_type(:string) }
  	it { is_expected.to have_db_column(:address_state).of_type(:string) }
  	it { is_expected.to have_db_column(:zip_code).of_type(:string) }
  	it { is_expected.to have_db_column(:level).of_type(:string) }
  	it { is_expected.to have_db_column(:custom_role).of_type(:string) }
  	it { is_expected.to have_db_column(:flsa_code).of_type(:string) }
  	it { is_expected.to have_db_column(:state).of_type(:string).with_options(default: 'active') }
  	it { is_expected.to have_db_column(:send_credentials_timezone).of_type(:string) }
  	it { is_expected.to have_db_column(:preferred_name).of_type(:string) }
    it { is_expected.to have_db_column(:jazz_hr_id).of_type(:string) }
  	it { is_expected.to have_db_column(:workday_id).of_type(:string) }
  	it { is_expected.to have_db_column(:workday_id_type).of_type(:string) }
  	it { is_expected.to have_db_column(:team_id).of_type(:integer) }
  	it { is_expected.to have_db_column(:location_id).of_type(:integer) }
  	it { is_expected.to have_db_column(:manager_id).of_type(:integer) }
  	it { is_expected.to have_db_column(:user_id).of_type(:integer) }
  	it { is_expected.to have_db_column(:base_salary).of_type(:integer).with_options(default: 0) }
  	it { is_expected.to have_db_column(:hourly_rate).of_type(:integer).with_options(default: 0) }
  	it { is_expected.to have_db_column(:bonus).of_type(:integer).with_options(default: 0) }
  	it { is_expected.to have_db_column(:send_credentials_type).of_type(:integer).with_options(default: 'immediately') }
  	it { is_expected.to have_db_column(:send_credentials_offset_before).of_type(:integer) }
  	it { is_expected.to have_db_column(:send_credentials_time).of_type(:integer).with_options(default: 8) }
  	it { is_expected.to have_db_column(:deleted_at).of_type(:datetime) }
  	it { is_expected.to have_db_column(:custom_fields).of_type(:json) }
  	it { is_expected.to have_db_column(:lever_custom_fields).of_type(:json) }
  	it { is_expected.to have_db_column(:workday_custom_fields).of_type(:json) }
  	it { is_expected.to have_db_column(:provision_gsuite).of_type(:boolean).with_options(default: true) }
  	it { is_expected.to have_db_column(:is_basic_format_custom_data).of_type(:boolean).with_options(default: true) }
  end

  describe 'enum' do
  	it { should define_enum_for(:send_credentials_type).with({ immediately: 0, before: 1, on: 2, dont_send: 3 }) }
  end

  describe 'validations' do
  	it { is_expected.to validate_presence_of(:company_id) }

  	context 'should validate user association uniqueness per company' do
  		before do
  			@pending_hire = create(:incomplete_pending_hire, company: company, user: incomplete_user, personal_email: 'unit_test@test.com')
  		end

  		it 'should be valid' do
  			@pending_hire.should be_valid
  		end

  		it 'should be invalid' do
  			expect { create(:incomplete_pending_hire, company: company, user: incomplete_user, personal_email: 'unit_test+1@test.com') }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: User has already been taken')
  		end
  	end

  	context 'should validate user existence per company on the basis of email' do
  		before do
  			@pending_hire = create(:incomplete_pending_hire, company: company, user: incomplete_user, personal_email: 'unit_test@test.com')
  		end

  		it 'should validate and create pending hire with email unit_test@test.com' do
  			@pending_hire.should be_valid
  		end

  		it 'should validate and halt pending hire creation with email unit_test@test.com if already exists in pending hires' do
  			expect { create(:pending_hire, company: company, personal_email: 'unit_test@test.com') }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Email User Already exists with same information.')
  		end

  		it 'should create pending_hire with duplicate email having different information' do
        pending_hire = create(:pending_hire, company: company, personal_email: user.email)
  			expect(pending_hire.duplication_type).to eq('info_change')
  		end

      it 'should create pending_hire with duplicate email having same information' do
        pending_hire = create(:pending_hire, company: company, personal_email: user.email, first_name: user.first_name, last_name: user.last_name)
        expect(pending_hire.duplication_type).to eq('active')
      end
  	end
  end

  describe 'callbacks' do
  	context 'after_create#send_pending_hire_notification' do
  		before do
  			company.update_column(:new_pending_hire_emails, true)
  			allow_any_instance_of(Interactions::Users::PendingHireNotificationEmail).to receive(:perform).and_return({send_email: true})
  		end

  		it 'should send email if pending hire onboarding is not started, and user association not exists' do
  			pending_hire = create(:pending_hire, company: company.reload, personal_email: 'unit_test@test.com')
  			expect(pending_hire.send_pending_hire_notification[:send_email]).to eq(true)
  		end

  		it 'should not send email if pending hire onboarding is started, and user association exists' do
  			pending_hire = create(:pending_hire, company: company.reload, user: incomplete_user, personal_email: 'unit_test@test.com')
  			expect(pending_hire.send_pending_hire_notification).to eq(nil)
  		end
  	end

    context 'before_create#set_start_date_to_nil' do
      it 'should convert start date to nil if empty' do
        pending_hire = create(:pending_hire, company: company, personal_email: 'unit_test@test.com', start_date: "")
        expect(pending_hire.reload.start_date).to eq(nil)
      end

      it 'should not convert start date to nil if not empty' do
        pending_hire = create(:pending_hire, company: company, personal_email: 'unit_test@test.com', start_date: 2.days.ago.to_date)
        expect(pending_hire.start_date).not_to eq(nil)
        expect(pending_hire.start_date.to_date).to eq(2.days.ago.to_date)
      end
    end
  end

  describe 'methods' do

  	context 'method#create_by_smart_recruiters' do
  		it 'should create smart recruiter pending hire' do
	  		data = { personal_email: 'unit@test.com', first_name: 'unit', last_name: 'test', title: 'unit tester', start_date: '2019-07-16T00:00:00+00:00',
	  			city: 'test', address_state: 'LA', employee_type: 'Full Time', company_id: company.id, department: 'marketing', location: 'location' }
	  		PendingHire.create_by_smart_recruiters(data, company)
	  		pending_hire = company.reload.pending_hires.take

				expect(pending_hire.personal_email).to eq(data[:personal_email])
				expect(pending_hire.first_name).to eq(data[:first_name])
				expect(pending_hire.last_name).to eq(data[:last_name])
				expect(pending_hire.title).to eq(data[:title])
				expect(pending_hire.start_date).to eq(data[:start_date])
				expect(pending_hire.city).to eq(data[:city])
				expect(pending_hire.address_state).to eq(data[:address_state])
				expect(pending_hire.employee_type).to eq(data[:employee_type])
        expect(pending_hire.team_id).to eq(company.teams.find_by(name: 'Marketing')&.id)
				expect(pending_hire.location_id).to eq(nil)
			end
  	end

    context 'method#create_by_workable' do
      it 'should create workable pending hire' do
        data = { first_name: 'unit', last_name: 'test', personal_email: 'unit_test@test.com', phone_number: '1111122222', start_date: '2019-07-16T00:00:00+00:00',
          title: 'unit tester', employee_type: 'Full Time', department: 'Marketing', location: 'New York' }
        PendingHire.create_by_workable(data, company)
        pending_hire = company.reload.pending_hires.take

        expect(pending_hire.personal_email).to eq(data[:personal_email])
        expect(pending_hire.first_name).to eq(data[:first_name])
        expect(pending_hire.last_name).to eq(data[:last_name])
        expect(pending_hire.title).to eq(data[:title])
        expect(pending_hire.start_date).to eq(data[:start_date])
        expect(pending_hire.phone_number).to eq(data[:phone_number])
        expect(pending_hire.employee_type).to eq(data[:employee_type])
        expect(pending_hire.team_id).to eq(company.teams.find_by(name: data[:department])&.id)
        expect(pending_hire.location_id).to eq(company.locations.find_by(name: data[:location])&.id)
      end
    end

    context 'method#create_by_greenhouse_mail_parser' do
      it 'should create greenhouse mail parser pending hire' do
        data = { 'first_name' => 'unit', 'last_name' => 'test', 'personal_email' => 'unit_test@test.com', 'phone_numbers' => '12121221212', 'start_date' => '2019-07-16T00:00:00+00:00',
          'job_title' => 'unit tester', 'employment_type' => 'full_time', 'location' => 'London', 'department' => 'Sales', 'manager' => user.full_name, 'base_salary' => 100,
          'hourly_rate' => 20, 'bonus' => 5, 'address_line_1' => 'line 1', 'address_line_2' => 'line 2', 'city' => 'city', 'state' => 'state', 'zip_code' => '1233',
          'level' => 'LA', 'role' => 'admin', 'flsa_code' => '234R' }
        PendingHire.create_by_greenhouse_mail_parser(data, company)
        pending_hire = company.reload.pending_hires.take

        expect(pending_hire.first_name).to eq(data['first_name'])
        expect(pending_hire.last_name).to eq(data['last_name'])
        expect(pending_hire.personal_email).to eq(data['personal_email'])
        expect(pending_hire.phone_number).to eq(data['phone_numbers'])
        expect(pending_hire.start_date).to eq(data['start_date'])
        expect(pending_hire.title).to eq(data['job_title'])
        expect(pending_hire.employee_type).to eq(data['employment_type'].parameterize.underscore)
        expect(pending_hire.base_salary).to eq(data['base_salary'])
        expect(pending_hire.hourly_rate).to eq(data['hourly_rate'])
        expect(pending_hire.bonus).to eq(data['bonus'])
        expect(pending_hire.address_line_1).to eq(data['address_line_1'])
        expect(pending_hire.address_line_2).to eq(data['address_line_2'])
        expect(pending_hire.city).to eq(data['city'])
        expect(pending_hire.address_state).to eq(data['state'])
        expect(pending_hire.zip_code).to eq(data['zip_code'])
        expect(pending_hire.level).to eq(data['level'])
        expect(pending_hire.custom_role).to eq(data['role'])
        expect(pending_hire.flsa_code).to eq(data['flsa_code'])
        expect(pending_hire.manager_id).to eq(user.id)
        expect(pending_hire.team_id).to eq(company.teams.find_by(name: data['department'])&.id)
        expect(pending_hire.location_id).to eq(company.locations.find_by(name: data['location'])&.id)
      end
    end

    context 'method#create_by_greenhouse' do
      it 'should create greenhouse pending hire for non ats mapping section' do
        candidate_data = { 'first_name' => 'unit', 'last_name' => 'test', 'email_addresses' => [{ 'value' => 'unit@test.com' }],
          'phone_numbers' => [{ 'value' => '12122221' }]}
        jobs_data = [{ 'name' => 'unit tester', 'offices' => [{ 'name' => 'London' }], 'departments' => [{ 'name' => 'Sales' }],
          'hiring_team' => { 'hiring_managers' => [{ 'employee_id' => user.id }]}}]
        offer_data = { 'starts_at' => '2019-07-16T00:00:00+00:00', 'custom_fields' => { 'employment_type' => { 'value' => 'Full Time' }} }

        data = { 'candidate' => candidate_data, 'jobs' => jobs_data, 'offer' => offer_data }
        PendingHire.create_by_greenhouse(data, company)
        pending_hire = company.reload.pending_hires.take

        expect(pending_hire.first_name).to eq(candidate_data['first_name'])
        expect(pending_hire.last_name).to eq(candidate_data['last_name'])
        expect(pending_hire.personal_email).to eq(candidate_data['email_addresses'][0]['value'])
        expect(pending_hire.phone_number).to eq(candidate_data['phone_numbers'][0]['value'])
        expect(pending_hire.title).to eq(jobs_data[0]['name'])
        expect(pending_hire.location_id).to eq(company.locations.find_by(name: jobs_data[0]['offices'][0]['name'])&.id)
        expect(pending_hire.team_id).to eq(company.teams.find_by(name: jobs_data[0]['departments'][0]['name'])&.id)
        expect(pending_hire.manager_id).to eq(user.id)
        expect(pending_hire.start_date).to eq(offer_data['starts_at'])
        expect(pending_hire.employee_type).to eq(offer_data['custom_fields']['employment_type']['value'])
      end

      it 'should create greenhouse pending hire for non ats mapping section if department and manager is nil' do
        candidate_data = { 'first_name' => 'unit', 'last_name' => 'test', 'email_addresses' => [{ 'value' => 'unit@test.com' }],
          'phone_numbers' => [{ 'value' => '12122221' }]}
        jobs_data = [{ 'name' => 'unit tester', 'offices' => [{ 'name' => 'London' }]}]
        offer_data = { 'starts_at' => '2019-07-16', 'custom_fields' => { 'employment_type' => { 'value' => 'Full Time' }} }

        data = { 'candidate' => candidate_data, 'jobs' => jobs_data, 'offer' => offer_data }
        PendingHire.create_by_greenhouse(data, company)
        pending_hire = company.reload.pending_hires.take

        expect(pending_hire.first_name).to eq(candidate_data['first_name'])
        expect(pending_hire.team_id).to eq(nil)
        expect(pending_hire.manager_id).to eq(nil)
      end

      it 'should create greenhouse pending hire for ats mapping section' do
        candidate_data = { 'first_name' => 'unit', 'last_name' => 'test', 'email_addresses' => [{ 'value' => 'unit@test.com' }],
          'phone_numbers' => [{ 'value' => '12122221' }], 'custom_fields' => { 'name' => { 'value' => 'Customname' },
          'department' => { 'name' => 'Department', 'type' => 'single_select', 'value' => ['Marketing'] } }}
        jobs_data = [{ 'name' => 'unit tester', 'offices' => [{ 'name' => 'London' }], 'departments' => [{ 'name' => 'Sales' }],
          'hiring_team' => { 'hiring_managers' => [{ 'employee_id' => '420' }]}, 'custom_fields' => { 'hiring_manager' => {
            'value' => { 'name' => user.full_name } } }}]
        offer_data = { 'starts_at' => '2019-07-16T00:00:00+00:00', 'custom_fields' => { 'employment_type' => { 'value' => 'Full Time' }} }

        data = { 'candidate' => candidate_data, 'jobs' => jobs_data, 'offer' => offer_data }

        preferences = company.prefrences
        preferences['default_fields'].each do |default_field|
          if ['fn', 'ln'].index(default_field['id']).present?
            default_field['ats_integration_group'] = 'greenhouse'
            default_field['ats_mapping_section'] = 'candidate'
            default_field['ats_mapping_key'] = 'name'
          elsif ['man'].index(default_field['id']).present?
            default_field['ats_integration_group'] = 'greenhouse'
            default_field['ats_mapping_section'] = 'jobs'
            default_field['ats_mapping_key'] = 'hiring_manager'
          elsif ['dpt'].index(default_field['id']).present?
            default_field['ats_integration_group'] = 'greenhouse'
            default_field['ats_mapping_section'] = 'candidate'
            default_field['ats_mapping_key'] = 'department'
          end
        end
        company.update(prefrences: preferences)
        PendingHire.create_by_greenhouse(data, company)
        pending_hire = company.reload.pending_hires.take

        expect(pending_hire.first_name).to eq(candidate_data['custom_fields']['name']['value'])
        expect(pending_hire.last_name).to eq(candidate_data['custom_fields']['name']['value'])
        expect(pending_hire.manager_id).to eq(user.id)
        expect(pending_hire.personal_email).to eq(candidate_data['email_addresses'][0]['value'])
        expect(pending_hire.phone_number).to eq(candidate_data['phone_numbers'][0]['value'])
        expect(pending_hire.title).to eq(jobs_data[0]['name'])
        expect(pending_hire.location_id).to eq(company.locations.find_by(name: jobs_data[0]['offices'][0]['name'])&.id)
        expect(pending_hire.team_id).to eq(company.teams.find_by(name: candidate_data['custom_fields']['department']['value'][0])&.id)
        expect(pending_hire.start_date).to eq(offer_data['starts_at'])
        expect(pending_hire.employee_type).to eq(offer_data['custom_fields']['employment_type']['value'])
      end
    end

    context 'method#create_by_lever' do
      before do
        @candidate_data = { 'name' => 'Unit Test', 'emails' => ['unit@test.com'], 'archived' => {'archivedAt' => 1562860495318}, 'sources' => ['xyzsource'], 'sources' => ['xyzsource'] }
        @hired_candidate_profile_form_fields = [ {'text' => 'start date', 'value' => 1562860495618}, {'text' => 'location', 'value' => 'London'} ]
        @candidate_hiring_manager = user.email
        @offer_data = {'fields' => [{'identifier' => 'anticipated_start_date', 'value' => 1562860497318}, {'identifier' => 'team', 'value' => 'Sales'}, {'identifier' => 'salary_amount', 'value' => 2300},
          {'identifier' => 'location', 'value' => 'New York'}, {'identifier' => 'custom', 'value' => 'custom_field'}]}
        @candidate_posting_data = {'text' => 'Unit tester', 'categories' => {'team' => 'Marketing', 'location' => 'Turkey', 'commitment' => 'Full Time'}}
        @referral_posting_data = { 'value' => 'xyzReferral'}
        @hired_candidate_requisition_posting_data = {'customFields' => [{'identifier' => 'name', 'value' => 'Unit Test'}, {'identifier' => 'requisitionCode', 'value' => 1562860497318}, {'identifier' => 'internalNotes', 'value' => 'abc'},
          {'identifier' => 'location', 'value' => 'New York'}]}
      end

      it 'should create lever pending hire' do
        PendingHire.create_by_lever(@candidate_data, {}, {}, {}, company, nil, @referral_posting_data, @hired_candidate_requisition_posting_data)
        pending_hire = company.reload.pending_hires.take
        start_date = DateTime.strptime(((@candidate_data['archived']['archivedAt'].to_i + ActiveSupport::TimeZone[company.time_zone].utc_offset).to_f / 1000).to_s, '%s').in_time_zone(company.time_zone).to_date rescue nil
        expect(pending_hire.first_name).to eq(@candidate_data['name'].split(' ', 2)[0])
        expect(pending_hire.last_name).to eq(@candidate_data['name'].split(' ', 2)[1])
        expect(pending_hire.personal_email).to eq(@candidate_data['emails'][0])
        expect(pending_hire.start_date.to_datetime).to eq(start_date)
        expect(pending_hire.lever_custom_fields.first['value']).to eq(@candidate_data['sources'][0])
        expect(pending_hire.lever_custom_fields.second['value']).to eq(@referral_posting_data['value'])
      end

      it 'should create lever pending hire and set start date from hired_candidate_profile_form_fields' do
        PendingHire.create_by_lever(@candidate_data, {}, {}, @hired_candidate_profile_form_fields, company)
        pending_hire = company.reload.pending_hires.take
				start_date = DateTime.strptime(((@hired_candidate_profile_form_fields[0]['value'].to_i + ActiveSupport::TimeZone[company.time_zone].utc_offset).to_f / 1000).to_s, '%s').in_time_zone(company.time_zone).to_date rescue nil

        expect(pending_hire.first_name).to eq(@candidate_data['name'].split(' ', 2)[0])
        expect(pending_hire.last_name).to eq(@candidate_data['name'].split(' ', 2)[1])
        expect(pending_hire.personal_email).to eq(@candidate_data['emails'][0])
        expect(pending_hire.start_date.to_datetime).to eq(start_date)
      end

      it 'should create lever pending hire and set start date from offer_data on priority basis and set manager from candidate_hiring_manager' do
        PendingHire.create_by_lever(@candidate_data, {}, @candidate_hiring_manager, @hired_candidate_profile_form_fields, company, @offer_data)
        pending_hire = company.reload.pending_hires.take
				start_date = DateTime.strptime(((@offer_data['fields'][0]['value'].to_i + ActiveSupport::TimeZone[company.time_zone].utc_offset).to_f / 1000).to_s, '%s').in_time_zone(company.time_zone).to_date rescue nil
        expect(pending_hire.first_name).to eq(@candidate_data['name'].split(' ', 2)[0])
        expect(pending_hire.last_name).to eq(@candidate_data['name'].split(' ', 2)[1])
        expect(pending_hire.personal_email).to eq(@candidate_data['emails'][0])
        expect(pending_hire.start_date.to_datetime).to eq(start_date)
        expect(pending_hire.manager_id).to eq(user.id)
      end

      it 'should create lever pending hire and set location/team/startdate from offer_data on priority basis' do
        PendingHire.create_by_lever(@candidate_data, @candidate_posting_data, @candidate_hiring_manager, @hired_candidate_profile_form_fields, company, @offer_data)
        start_date = DateTime.strptime(((@offer_data['fields'][0]['value'].to_i + ActiveSupport::TimeZone[company.time_zone].utc_offset).to_f / 1000).to_s, '%s').in_time_zone(company.time_zone).to_date rescue nil
        pending_hire = company.reload.pending_hires.take

        expect(pending_hire.first_name).to eq(@candidate_data['name'].split(' ', 2)[0])
        expect(pending_hire.last_name).to eq(@candidate_data['name'].split(' ', 2)[1])
        expect(pending_hire.personal_email).to eq(@candidate_data['emails'][0])
        expect(pending_hire.start_date.to_datetime).to eq(start_date)
        expect(pending_hire.base_salary).to eq(@offer_data['fields'][2]['value'])
        expect(pending_hire.team.name).to eq(@offer_data['fields'][1]['value'])
        expect(pending_hire.location.name).to eq(@offer_data['fields'][3]['value'])
        expect(pending_hire.employee_type).to eq(@candidate_posting_data['categories']['commitment'].parameterize.underscore)
        expect(pending_hire.lever_custom_fields.second['value']).to eq(@offer_data['fields'][2]['value'])
        expect(pending_hire.lever_custom_fields.third['value']).to eq(@offer_data['fields'][4]['value'])
      end

      it 'should create lever pending hire and set location from hired_candidate_profile_form_fields on priority basis' do
        @offer_data['fields'].slice!(3)
        @offer_data['fields'].slice!(0)

        PendingHire.create_by_lever(@candidate_data, @candidate_posting_data, @candidate_hiring_manager, @hired_candidate_profile_form_fields, company, @offer_data)
        start_date = DateTime.strptime(((@hired_candidate_profile_form_fields[0]['value'].to_i + ActiveSupport::TimeZone[company.time_zone].utc_offset).to_f / 1000).to_s, '%s').in_time_zone(company.time_zone).to_date rescue nil
        pending_hire = company.reload.pending_hires.take

        expect(pending_hire.first_name).to eq(@candidate_data['name'].split(' ', 2)[0])
        expect(pending_hire.last_name).to eq(@candidate_data['name'].split(' ', 2)[1])
        expect(pending_hire.personal_email).to eq(@candidate_data['emails'][0])
        expect(pending_hire.start_date.to_datetime).to eq(start_date)
        expect(pending_hire.title).to eq(@candidate_posting_data['text'])
        expect(pending_hire.team.name).to eq(@offer_data['fields'][0]['value'])
        expect(pending_hire.location.name).to eq(@hired_candidate_profile_form_fields[1]['value'])
        expect(pending_hire.employee_type).to eq(@candidate_posting_data['categories']['commitment'].parameterize.underscore)
      end

      it 'should create lever pending hire and set location/team from candidate_posting_data on priority basis' do
        @offer_data['fields'].slice!(3)
        @offer_data['fields'].slice!(0)
        @offer_data['fields'].slice!(0)
        @hired_candidate_profile_form_fields.slice!(1)

        PendingHire.create_by_lever(@candidate_data, @candidate_posting_data, @candidate_hiring_manager, @hired_candidate_profile_form_fields, company, @offer_data)
        start_date = DateTime.strptime(((@hired_candidate_profile_form_fields[0]['value'].to_i + ActiveSupport::TimeZone[company.time_zone].utc_offset).to_f / 1000).to_s, '%s').in_time_zone(company.time_zone).to_date rescue nil
        pending_hire = company.reload.pending_hires.take

        expect(pending_hire.first_name).to eq(@candidate_data['name'].split(' ', 2)[0])
        expect(pending_hire.last_name).to eq(@candidate_data['name'].split(' ', 2)[1])
        expect(pending_hire.personal_email).to eq(@candidate_data['emails'][0])
        expect(pending_hire.start_date.to_datetime).to eq(start_date)
        expect(pending_hire.title).to eq(@candidate_posting_data['text'])
        expect(pending_hire.team.name).to eq(@candidate_posting_data['categories']['team'])
        expect(pending_hire.location.name).to eq(@candidate_posting_data['categories']['location'])
        expect(pending_hire.employee_type).to eq(@candidate_posting_data['categories']['commitment'].parameterize.underscore)
      end
    end

    context 'method#hashed_phone_number' do
      it 'should return empty hash if no phone number exists' do
        expect(pending_hire.hashed_phone_number).to eq({})
      end

      it 'should return empty hash if phone number is invalid' do
        pending_hire.update_column(:phone_number, '958951787')
        expect(pending_hire.reload.hashed_phone_number).to eq({})
      end

      it 'should return phone number hash if phone number is valid - case 1' do
        pending_hire.update_column(:phone_number, '+57-3183932857')
        expect(pending_hire.reload.hashed_phone_number).to eq({:country_alpha3=>'COL', :area_code=>nil, :phone=>'3183932857'})
      end

      it 'should return phone number hash if phone number is valid - case 2' do
        pending_hire.update_column(:phone_number, '306946947024')
        expect(pending_hire.reload.hashed_phone_number).to eq({:country_alpha3=>'GRC', :area_code=>nil, :phone=>'6946947024'})
      end
    end
  end
end
