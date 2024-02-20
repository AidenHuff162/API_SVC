require 'rails_helper'

RSpec.describe CustomTableUserSnapshot, type: :model do

	let (:company) { create(:company, time_zone: "UTC") }
	let (:user_a) { create(:user, company: company) }
	let (:user_b) { create(:user, company: company) }
	let (:user_c) { create(:user, company: company) }
	let (:user_d) { create(:user, company: company) }
  let (:standard_custom_table_a) { create(:custom_table, company: company, table_type: CustomTable.table_types[:standard], name: 'Standard CustomTable A') }
  let (:standard_custom_table_b) { create(:custom_table, company: company, table_type: CustomTable.table_types[:standard], name: 'Standard CustomTable B') }
  let (:timeline_custom_table_a) { create(:custom_table, company: company, table_type: CustomTable.table_types[:timeline], name: 'Timeline CustomTable A') }
  let (:timeline_custom_table_b) { create(:custom_table, company: company, table_type: CustomTable.table_types[:timeline], name: 'Timeline CustomTable B') }
  let (:timeline_approval_chain_custom_table_a) { create(:approval_custom_table, company: company, approval_chains_attributes: [{ approval_type: ApprovalChain.approval_types[:person], approval_ids: [user_b.id]}, { approval_type: ApprovalChain.approval_types[:manager], approval_ids: ['1']}, { approval_type: ApprovalChain.approval_types[:person], approval_ids: [user_b.id]}]) }

  before do
    Date.stub(:today) {company.time.to_date}
		stub_request(:post, "https://api.sendgrid.com/v3/mail/send").to_return(status: 200, body: "", headers: {})
  end

  describe 'column specifications' do
    it { is_expected.to have_db_column(:custom_table_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:user_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:edited_by_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:effective_date).of_type(:date).with_options(presence: true) }
    it { is_expected.to have_db_column(:state).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:is_terminated).of_type(:boolean).with_options(presence: true, default: false) }
    it { is_expected.to have_db_column(:terminated_data).of_type(:json).with_options(presence: true) }
    it { is_expected.to have_db_column(:requester_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:terminated_data).of_type(:json).with_options(presence: true) }
    it { is_expected.to have_db_column(:request_state).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:deleted_at).of_type(:datetime).with_options(presence: true) }
    it { is_expected.to have_db_column(:integration_type).of_type(:integer).with_options(presence: true) }

    it { is_expected.to have_db_index(:custom_table_id) }
    it { is_expected.to have_db_index(:edited_by_id) }
    it { is_expected.to have_db_index(:user_id) }
  end

  describe "attributes accessors" do
  	subject { CustomTableUserSnapshot.new }

  	it "should check terminate_job_execution to be true" do
  		subject.terminate_job_execution = true
  		expect(subject.terminate_job_execution).to eq(true)
  	end

  	it "should check terminate_callback to be false" do
  		expect(subject.terminate_callback.blank?).to eq(true)
  	end

  	it "should check ctus_creation to be true" do
  		subject.ctus_creation = true
  		expect(subject.ctus_creation.blank?).to eq(false)
  	end

  	it "should check bypass_approval to be true" do
  		CustomTableUserSnapshot.bypass_approval = true
  		expect(CustomTableUserSnapshot.bypass_approval.blank?).to eq(false)
      CustomTableUserSnapshot.bypass_approval = false
  	end
  end

  describe "associations" do
    it { is_expected.to have_many(:custom_snapshots).dependent(:destroy) }
    it { is_expected.to belong_to(:edited_by).class_name('User') }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:custom_table) }
    it { is_expected.to have_many(:activities).dependent(:destroy) }
    it { is_expected.to have_many(:ctus_approval_chains).dependent(:destroy) }
    it { is_expected.to belong_to(:requester).class_name('User') }
  end

  describe "nested attributes" do
  	it { should accept_nested_attributes_for(:custom_snapshots).allow_destroy(true) }
  	it { should accept_nested_attributes_for(:activities).allow_destroy(true) }
    it { should accept_nested_attributes_for(:ctus_approval_chains).allow_destroy(true) }
  end

	describe "enums" do
		it { should define_enum_for(:state).with({ queue: 0, applied: 1, processed: 2 }) }
		it { should define_enum_for(:request_state).with({ denied: 0, requested: 1,  approved: 2 }) }
		it { should define_enum_for(:integration_type).with({ adp_integration_us: 0, adp_integration_can: 1, public_api: 2 }) }
	end

	describe "validations" do
    subject { CustomTableUserSnapshot.new(custom_table_id: timeline_approval_chain_custom_table_a.id, request_state: CustomTableUserSnapshot.request_states[:requested], requester_id: user_a.id, user_id: user_a.id) }

		it { is_expected.to validate_presence_of(:state) }

		context "should check state uniqueness" do
			it "should be valid" do
				create(:custom_table_user_snapshot, custom_table: standard_custom_table_a, user: user_a, state: CustomTableUserSnapshot.states[:applied]).should be_valid
			end

			it "should be invalid" do
				create(:custom_table_user_snapshot, custom_table: standard_custom_table_a, user: user_a, state: CustomTableUserSnapshot.states[:applied])
				expect { create(:custom_table_user_snapshot, custom_table: standard_custom_table_a, user: user_a, state: CustomTableUserSnapshot.states[:applied]) }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: State has already been taken")
			end
		end

    context 'custom validations' do

      it 'should throw state error on create' do
        user_b.update(manager_id: user_a.id)
        expect { FactoryGirl.create(:custom_table_user_snapshot, effective_date: Date.today, custom_table: timeline_approval_chain_custom_table_a, user: user_b, state: CustomTableUserSnapshot.states[:applied], request_state: CustomTableUserSnapshot.request_states[:approved], requester_id: user_a.id) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Request state is not included in the list')
      end
    end
	end

	describe "scopes" do
		context "#user_ctus" do
			before do
				create(:custom_table_user_snapshot, user: user_a, custom_table: standard_custom_table_a)
				create(:custom_table_user_snapshot, user: user_a, custom_table: standard_custom_table_a)
				create(:custom_table_user_snapshot, user: user_b, custom_table: standard_custom_table_a)
				create(:custom_table_user_snapshot, user: user_b, custom_table: standard_custom_table_b)
			end

			it "should return data of user_a and standard_custom_table_a - case 1" do
				expect(CustomTableUserSnapshot.user_ctus(user_a.id, standard_custom_table_a.id).pluck(:user_id, :custom_table_id).uniq[0]).to eq([user_a.id, standard_custom_table_a.id])
			end

			it "should return data of user_a and standard_custom_table_b - case 2" do
				expect(CustomTableUserSnapshot.user_ctus(user_a.id, standard_custom_table_b.id).pluck(:user_id, :custom_table_id).uniq).to eq([])
			end
		end

    context "#greater_snapshot_exists" do
      before do
        create(:timeline_without_approval, user: user_a, custom_table: timeline_custom_table_a, effective_date: Date.today-10.days)
        create(:timeline_without_approval, user: user_a, custom_table: timeline_custom_table_a, effective_date: Date.today-5.days)
        create(:timeline_without_approval, user: user_a, custom_table: timeline_custom_table_a, effective_date: Date.today+3.days)
        create(:timeline_without_approval, user: user_a, custom_table: timeline_custom_table_a, effective_date: Date.today)
        create(:timeline_without_approval, user: user_b, custom_table: timeline_custom_table_a, effective_date: Date.today)
        create(:timeline_without_approval, user: user_b, custom_table: timeline_custom_table_a, effective_date: Date.today+12.days)
      end

      it "should return data of user_a, timeline_custom_table_a and date range(date.today-6.days to date.today-1) - case 1" do
        expect(CustomTableUserSnapshot.greater_snapshot_exists(user_a.id, timeline_custom_table_a.id, (Date.today-6), (Date.today-1)).count).to eq(1)
      end

      it "should return data of user_b, timeline_custom_table_a and date range(date.today-6.days to date.today) - case 2" do
        expect(CustomTableUserSnapshot.greater_snapshot_exists(user_b.id, timeline_custom_table_a.id, (Date.today-6), (Date.today)).count).to eq(1)
      end

      it "should return data of user_a, timeline_custom_table_a and date range(date.today-12.days to date.today) - case 3" do
        expect(CustomTableUserSnapshot.greater_snapshot_exists(user_a.id, timeline_custom_table_a.id, (Date.today-12), (Date.today)).count).to eq(3)
      end
    end

    context "#process_user_ctus_state" do
      before do
        create(:timeline_without_approval, user: user_a, custom_table: timeline_custom_table_a, effective_date: Date.today-10.days)
        create(:timeline_without_approval, user: user_a, custom_table: timeline_custom_table_a, effective_date: Date.today+3.days)
        create(:timeline_without_approval, user: user_a, custom_table: timeline_custom_table_a, effective_date: Date.today)
        create(:timeline_without_approval, user: user_b, custom_table: timeline_custom_table_a, effective_date: Date.today)
      end

      it "should processed ctus state of user_a, timeline_custom_table_a and date range(date.today) - case 1" do
        CustomTableUserSnapshot.process_user_ctus_state(user_a.id, timeline_custom_table_a.id, Date.today, nil)
        expect(user_a.custom_table_user_snapshots.where('effective_date <= ? AND custom_table_id = ?', Date.today, timeline_custom_table_a.id).pluck(:state).count).to eq(2)
        expect(user_a.custom_table_user_snapshots.where('effective_date <= ? AND custom_table_id = ?', Date.today, timeline_custom_table_a.id).pluck(:state).uniq).to eq(["processed"])
      end

      it "should processed ctus state of user_a, timeline_custom_table_a and date range(date.today+6.days) - case 2" do
         CustomTableUserSnapshot.process_user_ctus_state(user_a.id, timeline_custom_table_a.id, Date.today+6.days, nil)
        expect(user_a.custom_table_user_snapshots.where('effective_date <= ? AND custom_table_id = ?', Date.today+6.days, timeline_custom_table_a.id).pluck(:state).count).to eq(3)
        expect(user_a.custom_table_user_snapshots.where('effective_date <= ? AND custom_table_id = ?', Date.today+6.days, timeline_custom_table_a.id).pluck(:state).uniq).to eq(["processed"])
      end

      it "should not processed ctus state of user_b, timeline_custom_table_a and date range(date.today+6.days) - case 3" do
        CustomTableUserSnapshot.process_user_ctus_state(user_a.id, timeline_custom_table_a.id, Date.today+6.days, nil)
        expect(user_b.custom_table_user_snapshots.where('effective_date <= ? AND custom_table_id = ?', Date.today+6.days, timeline_custom_table_a.id).pluck(:state).uniq).to eq(["applied"])
      end
    end

    context "#process_standard_ctus" do
      before do
        create(:custom_table_user_snapshot, user: user_a, custom_table: standard_custom_table_a)
        create(:custom_table_user_snapshot, user: user_a, custom_table: standard_custom_table_a)
        create(:custom_table_user_snapshot, user: user_b, custom_table: standard_custom_table_a)
        CustomTableUserSnapshot.process_standard_ctus(user_a.id, standard_custom_table_a.id, Date.today+3.day)
      end

      it "should processed ctus state of user_a, standard_custom_table_a and date range(date.today+3)" do
        expect(user_a.custom_table_user_snapshots.where('created_at <= ? AND custom_table_id = ?', Date.today+3.day, standard_custom_table_a.id).pluck(:state).uniq).to eq(["processed"])
      end

      it "should not processed ctus state of user_b, standard_custom_table_a and date range(date.today+3)" do
        expect(user_b.custom_table_user_snapshots.where('created_at <= ? AND custom_table_id = ?', Date.today+3.day, standard_custom_table_a.id).pluck(:state).uniq).to eq(["applied"])
      end
    end

    context "#queue_user_ctus_state" do
      before do
        create(:timeline_without_approval, user: user_a, custom_table: timeline_custom_table_a, effective_date: Date.today-10.days)
        create(:timeline_without_approval, user: user_a, custom_table: timeline_custom_table_a, effective_date: Date.today-9.days)
        create(:timeline_without_approval, user: user_a, custom_table: timeline_custom_table_a, effective_date: Date.today-6.days)
        create(:timeline_without_approval, user: user_a, custom_table: timeline_custom_table_a, effective_date: Date.today-3.days)
        create(:timeline_without_approval, user: user_a, custom_table: timeline_custom_table_a, effective_date: Date.today)
        create(:timeline_without_approval, user: user_b, custom_table: timeline_custom_table_a, effective_date: Date.today-9.days)
        create(:timeline_without_approval, user: user_b, custom_table: timeline_custom_table_a, effective_date: Date.today)

        CustomTableUserSnapshot.queue_user_ctus_state(user_a.id, timeline_custom_table_a.id, Date.today-6.days)
      end

      it "should queued ctus state of user_a, timeline_custom_table_a and date range(> date.today-6) - case 1" do
        expect(user_a.custom_table_user_snapshots.where('effective_date > ? AND custom_table_id = ?', Date.today-6.days, timeline_custom_table_a.id).pluck(:state).uniq).to eq(["queue"])
      end

      it "should not queued ctus state of user_a, timeline_custom_table_a and date range(< date.today-6) - case 2" do
        expect(user_a.custom_table_user_snapshots.where('effective_date <= ? AND custom_table_id = ?', Date.today-6.days, timeline_custom_table_a.id).pluck(:state).uniq).to eq(["processed"])
      end

      it "should not queued ctus state of user_b, timeline_custom_table_a and date range(< date.today-6) - case 3" do
        expect(user_b.custom_table_user_snapshots.where('effective_date <= ? AND custom_table_id = ?', Date.today-6.days, timeline_custom_table_a.id).pluck(:state).uniq).to eq(["processed"])
      end
    end

    context "#get_latest_approved_ctus" do
      before do
        create(:timeline_with_approval, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: Date.today-12.days, request_state: CustomTableUserSnapshot.request_states[:approved], state:CustomTableUserSnapshot.states[:processed])
        create(:timeline_with_approval, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: Date.today-9.days, request_state: CustomTableUserSnapshot.request_states[:approved], state:CustomTableUserSnapshot.states[:processed])
        create(:timeline_with_approval, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: Date.today-6.days, request_state: CustomTableUserSnapshot.request_states[:approved], state:CustomTableUserSnapshot.states[:processed])
        create(:timeline_with_approval, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: Date.today-3.days, request_state: CustomTableUserSnapshot.request_states[:approved], state:CustomTableUserSnapshot.states[:processed])
        create(:timeline_with_approval, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: Date.today, request_state: CustomTableUserSnapshot.request_states[:approved], state:CustomTableUserSnapshot.states[:queue])
        create(:timeline_with_approval, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: Date.today+3.days, request_state: CustomTableUserSnapshot.request_states[:approved], state:CustomTableUserSnapshot.states[:queue])
      end

      it "should return count of latest approved ctus of user_a and timeline_approval_custom_table_a" do
        expect(CustomTableUserSnapshot.get_latest_approved_ctus(user_a.id, timeline_approval_chain_custom_table_a.id).count).to eq(4)
      end

      it "should return effective date of first index as date.today-3.days of latest approved ctus of user_a and timeline_approval_custom_table_a" do
        expect(CustomTableUserSnapshot.get_latest_approved_ctus(user_a.id, timeline_approval_chain_custom_table_a.id).take.effective_date).to eq(Date.today-3.days)
      end
    end

    context "#get_future_termination_based_snapshots" do
      before do
        create(:timeline_without_approval, user: user_a, custom_table: timeline_custom_table_a, effective_date: Date.today-10.days)
        create(:timeline_without_approval, user: user_a, custom_table: timeline_custom_table_a, effective_date: Date.today+3.days)
        create(:timeline_without_approval, user: user_a, custom_table: timeline_custom_table_b, effective_date: Date.today+6.days)
        create(:timeline_without_approval, user: user_a, custom_table: timeline_custom_table_a, effective_date: Date.today)
      end

      it "should return count of future snapshots of user_a and date range(date.today)" do
        expect(CustomTableUserSnapshot.get_future_termination_based_snapshots(user_a.id, Date.today).count).to eq(2)
      end

      it "should return count of future snapshots of user_a and date range(date.today+4.days)" do
        expect(CustomTableUserSnapshot.get_future_termination_based_snapshots(user_a.id, Date.today+4.days).count).to eq(1)
      end
    end
	end

  describe "callbacks" do
    context "manage custom table user snapshot approval chains" do
     context "after_create #create_ctus_approval_chains" do
        it 'should create ctus approval chains after creating timeline table approval snapshot' do
          user_a.update(manager_id: user_b.id)
          timline_custom_table_user_snapshot_a = create(:timeline_with_approval_with_custom_snapshots, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: 1.days.ago, state: CustomTableUserSnapshot.states[:queue],
            requester_id: user_a.id, custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])

          expect(timline_custom_table_user_snapshot_a.reload.ctus_approval_chains.count).to eq(3)
        end

        it 'should not create ctus approval chains after creating standard table  snapshot' do
          standard_custom_table_user_snapshot_a = create(:standard_with_custom_snapshots, user: user_a, custom_table: standard_custom_table_a, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])

          expect(standard_custom_table_user_snapshot_a.reload.ctus_approval_chains.count).to eq(0)
        end
     end

     context "after_update #dispatch_request_change_email" do
        before do
          user_a.update(manager_id: user_b.id)
          @timline_custom_table_user_snapshot_a = create(:timeline_with_approval_with_custom_snapshots, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: 1.days.ago, state: CustomTableUserSnapshot.states[:queue],
            requester_id: user_a.id, custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          @delivery_count = CompanyEmail.count
        end

        it 'should dispatch request change email if timeline approval snapshot was updated' do
          Sidekiq::Testing.inline! do
            User.current = user_a
            @timline_custom_table_user_snapshot_a.ctus_approval_chains.first.update(request_state: CtusApprovalChain.request_states[:approved])
            expect { @timline_custom_table_user_snapshot_a.update(request_state: CtusApprovalChain.request_states[:requested]) }.to change { CompanyEmail.count }.by(1)
          end
        end
     end
    end

    context "manage standard custom table user snapshots" do
      context "after create #manage_standard_ctus_creation" do
        it "should initialize the state of ctus as applied and apply values to user after create if no other ctuses exist" do
          standard_custom_table_user_snapshot_a = create(:standard_with_custom_snapshots, user: user_a, custom_table: standard_custom_table_a, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          expect(standard_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
          expect(user_a.reload.title).to eq('Software Tester A')
        end

        it "should initialize the state of latest ctus as applied and apply values to user after create if other ctuses exist" do
          standard_custom_table_user_snapshot_a = create(:standard_with_custom_snapshots, user: user_a, custom_table: standard_custom_table_a, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          standard_custom_table_user_snapshot_b = create(:standard_with_custom_snapshots, user: user_a, custom_table: standard_custom_table_a, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester B', preference_field_id: 'jt'}])

          expect(standard_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
          expect(user_a.reload.title).to eq('Software Tester B')
        end

        it "should initialize the state of previous ctus as processed after create if latest ctus exist and apply value of lastest ctus" do
          standard_custom_table_user_snapshot_a = create(:standard_with_custom_snapshots, user: user_a, custom_table: standard_custom_table_a, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          standard_custom_table_user_snapshot_b = create(:standard_with_custom_snapshots, user: user_a, custom_table: standard_custom_table_a, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester B', preference_field_id: 'jt'}])

          expect(standard_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:processed]])
          expect(user_a.reload.title).to eq('Software Tester B')
        end
      end

      context "after update #manage_standard_ctus_updation" do
        it "should apply updated custom snapshot and not change the state of the applied ctus after update if no other ctuses exist" do
          standard_custom_table_user_snapshot_a = create(:standard_with_custom_snapshots, user: user_a, custom_table: standard_custom_table_a, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          expect(user_a.reload.title).to eq('Software Tester A')
          expect(standard_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])

          standard_custom_table_user_snapshot_a.update!(custom_snapshots_attributes: [{custom_field_value: 'Software Tester C', preference_field_id: 'jt'}])
          expect(user_a.reload.title).to eq('Software Tester C')
          expect(standard_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
        end

        it "should apply updated custom snapshot and not change the state of the applied ctus after update if other ctuses exist" do
          standard_custom_table_user_snapshot_a = create(:standard_with_custom_snapshots, user: user_a, custom_table: standard_custom_table_a, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          standard_custom_table_user_snapshot_b = create(:standard_with_custom_snapshots, user: user_a, custom_table: standard_custom_table_a, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester B', preference_field_id: 'jt'}])
          expect(user_a.reload.title).to eq('Software Tester B')
          expect(standard_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:processed]])
          expect(standard_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])

          standard_custom_table_user_snapshot_b.update(custom_snapshots_attributes: [{custom_field_value: 'Software Tester C', preference_field_id: 'jt'}])
          expect(user_a.reload.title).to eq('Software Tester C')
          expect(standard_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:processed]])
          expect(standard_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
        end

        it "should not apply updated custom snapshot and chang the state of the processed ctus after update if other ctuses exist" do
          standard_custom_table_user_snapshot_a = create(:standard_with_custom_snapshots, user: user_a, custom_table: standard_custom_table_a, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          standard_custom_table_user_snapshot_b = create(:standard_with_custom_snapshots, user: user_a, custom_table: standard_custom_table_a, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester B', preference_field_id: 'jt'}])
          expect(user_a.reload.title).to eq('Software Tester B')
          expect(standard_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:processed]])
          expect(standard_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])

          standard_custom_table_user_snapshot_a.update(custom_snapshots_attributes: [{custom_field_value: 'Software Tester C', preference_field_id: 'jt'}])
          expect(user_a.reload.title).to eq('Software Tester B')
          expect(standard_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:processed]])
          expect(standard_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
        end
      end

      context "after destroy #manage_standard_ctus_deletion" do
        it "should not change the value of applied custom snapshot of only existing ctus after destroy" do
          standard_custom_table_user_snapshot_a = create(:standard_with_custom_snapshots, user: user_a, custom_table: standard_custom_table_a, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          expect(user_a.reload.title).to eq('Software Tester A')

          standard_custom_table_user_snapshot_a.really_destroy!
          expect(user_a.reload.title).to eq('Software Tester A')
        end

        it "should not apply custom snapshot and change state as processed of previous ctus after destroy if previous ctus is being destroyed" do
          standard_custom_table_user_snapshot_a = create(:standard_with_custom_snapshots, user: user_a, custom_table: standard_custom_table_a, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          standard_custom_table_user_snapshot_b = create(:standard_with_custom_snapshots, user: user_a, custom_table: standard_custom_table_a, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester B', preference_field_id: 'jt'}])
          expect(user_a.reload.title).to eq('Software Tester B')
          expect(standard_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])

          standard_custom_table_user_snapshot_a.really_destroy!
          expect(user_a.reload.title).to eq('Software Tester B')
          expect(standard_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
        end

        it "should apply custom snapshot and change state as applied  of previous ctus after destroy if latest ctus is being destroyed" do
          standard_custom_table_user_snapshot_a = create(:standard_with_custom_snapshots, user: user_a, custom_table: standard_custom_table_a, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          standard_custom_table_user_snapshot_b = create(:standard_with_custom_snapshots, user: user_a, custom_table: standard_custom_table_a, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester B', preference_field_id: 'jt'}])
          expect(standard_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:processed]])
          expect(user_a.reload.title).to eq('Software Tester B')

          standard_custom_table_user_snapshot_b.destroy!
          expect(user_a.reload.title).to eq('Software Tester A')
          expect(standard_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
        end
      end
    end

    context "manage timeline custom table user snapshots without approval" do
      context "after save #manage_past_timeline_snapshots_without_approval" do
        it "should initialize the state of ctus as applied and apply custom snapshot after save if no other ctuses exist" do
          timline_custom_table_user_snapshot_a = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 2.days.from_now, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])

          expect(timline_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
          expect(user_a.reload.title).to eq('Software Tester A')
        end

        it "should initialize the state of latest ctus as processed and not apply custom snapshot after save if other ctuses exist are greater effective date then latest ctus and less then current date" do
          timline_custom_table_user_snapshot_a = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 3.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          timline_custom_table_user_snapshot_b = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 5.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester B', preference_field_id: 'jt'}])

          expect(user_a.reload.title).to eq('Software Tester A')
          expect(timline_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
          expect(timline_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:processed]])
        end

        it "should initialize the state of latest ctus as applied and apply the custom snapshot and change state of previous ctus as processed after save if other ctuses has less effective date" do
          timline_custom_table_user_snapshot_a = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 7.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          timline_custom_table_user_snapshot_b = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 5.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester B', preference_field_id: 'jt'}])

          expect(user_a.reload.title).to eq('Software Tester B')
          expect(timline_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:processed]])
          expect(timline_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
        end

        it "should initialize the state of latest ctus as applied and apply the custom snapshot after save if other ctuses exist which are greater than effective date" do
          timline_custom_table_user_snapshot_a = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 2.days.from_now, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          timline_custom_table_user_snapshot_b = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester B', preference_field_id: 'jt'}])

          expect(user_a.reload.title).to eq('Software Tester B')
          expect(timline_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:queue]])
          expect(timline_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
        end

        it "should initialize the state of future ctus as queue and not apply the custom snapshot after save if other ctuses exist" do
          timline_custom_table_user_snapshot_a = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 2.days.from_now, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          timline_custom_table_user_snapshot_b = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 5.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester B', preference_field_id: 'jt'}])

          expect(user_a.reload.title).to eq('Software Tester B')
          expect(timline_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:queue]])
          expect(timline_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
        end
      end

      context "after save #manage_future_timeline_snapshots_without_approval" do
        it "should initialize the state of ctus as applied and apply custom snapshot after save if no other ctuses exist" do
          timline_custom_table_user_snapshot_a = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 2.days.from_now, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])

          expect(user_a.reload.title).to eq('Software Tester A')
          expect(timline_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
        end

        it "should initialize the state of latest ctus as queue and previous ctus as applied and not apply custom snapshot after save if other ctuses exist are less effective date then latest ctus and greater then current date" do
          timline_custom_table_user_snapshot_a = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 3.days.from_now, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          timline_custom_table_user_snapshot_b = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 5.days.from_now, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester B', preference_field_id: 'jt'}])

          expect(user_a.reload.title).to eq('Software Tester A')
          expect(timline_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
          expect(timline_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:queue]])
        end

        it "should initialize the state of future ctus as queue and not apply the custom snapshot after save if other ctuses exist" do
          timline_custom_table_user_snapshot_a = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 2.days.from_now, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          timline_custom_table_user_snapshot_b = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 1.days.from_now, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester B', preference_field_id: 'jt'}])

          expect(user_a.reload.title).to eq('Software Tester B')
          expect(timline_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:queue]])
          expect(timline_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
        end
      end

      context "after destroy #manage_without_approval_timeline_ctus" do
        it "should not change the value of applied custom snapshot of only existing ctus after destroy" do
          timline_custom_table_user_snapshot_a = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 1.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])

          expect(user_a.reload.title).to eq('Software Tester A')

          timline_custom_table_user_snapshot_a.really_destroy!
          expect(user_a.reload.title).to eq('Software Tester A')
        end

        it "should not apply custom snapshot of previous ctus and not change state of latest ctus as processed after destroy if previous ctus is being destroyed" do
          timline_custom_table_user_snapshot_a = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          timline_custom_table_user_snapshot_b = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 1.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester B', preference_field_id: 'jt'}])

          expect(timline_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:processed]])
          expect(timline_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
          expect(user_a.reload.title).to eq('Software Tester B')

          timline_custom_table_user_snapshot_a.really_destroy!
          expect(user_a.reload.title).to eq('Software Tester B')
          expect(timline_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
        end

        it "should apply custom snapshot of previous ctus and change state of previous ctus as applied after destroy if latest ctus is being destroyed" do
          timline_custom_table_user_snapshot_a = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          timline_custom_table_user_snapshot_b = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 1.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester B', preference_field_id: 'jt'}])
          expect(user_a.reload.title).to eq('Software Tester B')
          expect(timline_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:processed]])
          expect(timline_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])

          timline_custom_table_user_snapshot_b.destroy!
          expect(user_a.reload.title).to eq('Software Tester A')
          expect(timline_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
        end
      end
    end

    context 'manage timeline custom table user snapshots with approval' do
      before do
        CustomTableUserSnapshot.bypass_approval = false
      end
      context "after update #manage_with_approval_updated_snapshots" do
        it "should update state to apply of past snapshot and apply past snapshot if ctus is approved" do
          timline_custom_table_user_snapshot_a = create(:timeline_with_approval_with_custom_snapshots, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: 1.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])

          expect(timline_custom_table_user_snapshot_a.reload.state).to eq('queue')
          expect(user_a.reload.title).not_to eq('Software Tester A')

          timline_custom_table_user_snapshot_a.update!(request_state: CustomTableUserSnapshot.request_states[:approved])
          expect(timline_custom_table_user_snapshot_a.reload.state).to eq('applied')
          expect(user_a.reload.title).to eq('Software Tester A')
        end

        it "should queue future snapshot and not apply future snapshot if ctus is approved" do
          timline_custom_table_user_snapshot_a = create(:timeline_with_approval_with_custom_snapshots, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: company.time.to_date + 3.day, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          expect(timline_custom_table_user_snapshot_a.reload.state).to eq('queue')
          expect(user_a.reload.title).not_to eq('Software Tester A')

          timline_custom_table_user_snapshot_a.update!(request_state: CustomTableUserSnapshot.request_states[:approved])
          expect(timline_custom_table_user_snapshot_a.reload.state).to eq('queue')
          expect(user_a.reload.title).not_to eq('Software Tester A')
        end
      end

      context "after destroy #manage_with_approval_timeline_ctus" do
        it "should not change the value of applied custom snapshot of only existing ctus after destroy" do
          timline_custom_table_user_snapshot_a = create(:timeline_with_approval_with_custom_snapshots, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: 1.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
         timline_custom_table_user_snapshot_a.update!(request_state: CustomTableUserSnapshot.request_states[:approved])
          expect(user_a.reload.title).to eq('Software Tester A')

          timline_custom_table_user_snapshot_a.really_destroy!
          expect(user_a.reload.title).to eq('Software Tester A')
        end

        it "should not change state of latest ctus as processed  and not apply value of lastest ctus after destroy if previous ctus is being destroyed" do
          timline_custom_table_user_snapshot_a = create(:timeline_with_approval_with_custom_snapshots, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          timline_custom_table_user_snapshot_b = create(:timeline_with_approval_with_custom_snapshots, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: 1.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester B', preference_field_id: 'jt'}])
          timline_custom_table_user_snapshot_a.update!(request_state: CustomTableUserSnapshot.request_states[:approved])
          timline_custom_table_user_snapshot_b.update!(request_state: CustomTableUserSnapshot.request_states[:approved])

          expect(timline_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:processed]])
          expect(timline_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
          expect(user_a.reload.title).to eq('Software Tester B')

          timline_custom_table_user_snapshot_a.really_destroy!
          expect(timline_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
          expect(user_a.reload.title).to eq('Software Tester B')
        end

        it "should apply custom snapshot and change state of previous approved ctus as applied after destroy if latest ctus is being destroyed" do
          timline_custom_table_user_snapshot_a = create(:timeline_with_approval_with_custom_snapshots, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          timline_custom_table_user_snapshot_b = create(:timeline_with_approval_with_custom_snapshots, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: 1.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester B', preference_field_id: 'jt'}])
          timline_custom_table_user_snapshot_a.update!(request_state: CustomTableUserSnapshot.request_states[:approved])
          timline_custom_table_user_snapshot_b.update!(request_state: CustomTableUserSnapshot.request_states[:approved])

          expect(user_a.reload.title).to eq('Software Tester B')
          expect(timline_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:processed]])
          expect(timline_custom_table_user_snapshot_b.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])

          timline_custom_table_user_snapshot_b.destroy!
          expect(user_a.reload.title).to eq('Software Tester A')
          expect(timline_custom_table_user_snapshot_a.reload.state).to eq(CustomTableUserSnapshot.states.keys[CustomTableUserSnapshot.states[:applied]])
        end
      end

      context "after update #manage_past_timeline_approved_snapshots" do
        it "should change the state of latest ctus to applied and process the previous ctus and apply the latest ctus if other ctuses has less effective date" do
          @timline_custom_table_user_snapshot_a = create(:timeline_with_approval_with_custom_snapshots, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
          @timline_custom_table_user_snapshot_b = create(:timeline_with_approval_with_custom_snapshots, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: 1.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester B', preference_field_id: 'jt'}])
          @timline_custom_table_user_snapshot_a.update!(request_state: CustomTableUserSnapshot.request_states[:approved])
          @timline_custom_table_user_snapshot_b.update!(request_state: CustomTableUserSnapshot.request_states[:approved])

          expect(@timline_custom_table_user_snapshot_a.reload.state).to eq('processed')
          expect(@timline_custom_table_user_snapshot_b.reload.state).to eq('applied')
          expect(user_a.reload.title).to eq('Software Tester B')
        end
      end
    end

    context 'approval emails' do
      before do
        user_a.update(manager_id: user_b.id)
        @delivery_count = CompanyEmail.count
      end

      # context 'after_create #dispatch_request_change_email' do  
      #   it 'should dispatch request change email' do  
      #     Sidekiq::Testing.inline! do 
      #       timline_custom_table_user_snapshot_a = create(:timeline_with_approval_with_custom_snapshots, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: 2.days.ago, requester_id: user_b.id, state: CustomTableUserSnapshot.states[:queue],  
      #       custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])  
      #     end 
      #     expect(CompanyEmail.count).to eq(@delivery_count+1) 
      #   end 

      #   it 'should not dispatch request change email if custom table is non approval type' do 
      #     Sidekiq::Testing.inline! do 
      #       timline_custom_table_user_snapshot_a = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue], 
      #       custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])  
      #     end 
      #     expect(CompanyEmail.count).to eq(@delivery_count) 
      #   end 
      # end
      
      context 'after_update #dispatch_approved_denied_email' do
        it 'should dispatch approved denied email' do
           Sidekiq::Testing.inline! do
            User.current = user_a
            timline_custom_table_user_snapshot_a = create(:timeline_with_approval_with_custom_snapshots, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: 2.days.ago, requester_id: user_a.id, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
            timline_custom_table_user_snapshot_a.ctus_approval_chains.update_all(request_state: CtusApprovalChain.request_states[:approved])
            timline_custom_table_user_snapshot_a.update!(request_state: CustomTableUserSnapshot.request_states[:approved])
          end
          expect(CompanyEmail.count).to eq(@delivery_count+2)
        end

        it 'should not dispatch approved denied email if custom table is non approval type' do
          Sidekiq::Testing.inline! do
            timline_custom_table_user_snapshot_a = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
           timline_custom_table_user_snapshot_a.update!(request_state: CustomTableUserSnapshot.request_states[:approved])
          end
          expect(CompanyEmail.count).to eq(@delivery_count)
        end
      end

      context 'after_destroy #dispatch_approved_denied_email' do
        it 'should dispatch approved denied email' do
          Sidekiq::Testing.inline! do
            timline_custom_table_user_snapshot_a = create(:timeline_with_approval_with_custom_snapshots, user: user_a, custom_table: timeline_approval_chain_custom_table_a, effective_date: 2.days.ago, requester_id: user_a.id, state: CustomTableUserSnapshot.states[:queue],
              custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
            timline_custom_table_user_snapshot_a.really_destroy!
          end
          expect(CompanyEmail.count).to eq(@delivery_count+2)
        end

        it 'should not dispatch approved denied email if custom table is non approval type' do
          Sidekiq::Testing.inline! do
            timline_custom_table_user_snapshot_a = create(:timeline_without_approval_with_custom_snapshots, user: user_a, custom_table: timeline_custom_table_a, effective_date: 2.days.ago, state: CustomTableUserSnapshot.states[:queue],
            custom_snapshots_attributes: [{custom_field_value: 'Software Tester A', preference_field_id: 'jt'}])
            timline_custom_table_user_snapshot_a.really_destroy!
          end
          expect(CompanyEmail.count).to eq(@delivery_count)
        end
      end
    end
  end
end
