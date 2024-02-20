require 'rails_helper'

RSpec.describe PaperworkRequest, type: :model do
  let(:company) { create(:company, subdomain: 'paperwork_request') }
  let (:user) { create(:user, company: company) }
  let (:requester) { create(:sarah, company: company) }
  let(:document) { create(:document_with_drafted_paperwork_template, title: 'title', company_id: company.id) }
  let(:document_with_saved_template) { create(:document_with_paperwork_template, title: 'title', company_id: company.id) }
  let(:paperwork_packet) { create(:paperwork_packet, company: company) }
  let(:request) { create(:paperwork_request, :request_skips_validate, document_id: document_with_saved_template.id, user_id: user.id, state: 'signed', signed_document: nil, unsigned_document: nil, hellosign_signature_request_id: '123') }
  let(:draft_request) { create(:paperwork_request, :request_skips_validate, document_id: document_with_saved_template.id, template_ids: [document_with_saved_template.paperwork_template.id], user_id: user.id, requester: user, state: 'draft', co_signer_id: user.id, unsigned_document: nil, hellosign_signature_request_id: '123') }
  let(:request1) { create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'all_signed', signed_document: nil) }
  let(:request2) { create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'assigned', signed_document: nil) }

  describe 'column specifications' do
    it { is_expected.to have_db_column(:user_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:document_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:hellosign_signature_id).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:hellosign_signature_request_id).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime).with_options(presence: true, null: false) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime).with_options(presence: true, null: false) }
    it { is_expected.to have_db_column(:state).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:requester_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:signed_document).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:deleted_at).of_type(:datetime).with_options(presence: true) }
    it { is_expected.to have_db_column(:paperwork_packet_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:template_ids).of_type(:integer).with_options(presence: true, array: true, default: []) }
    it { is_expected.to have_db_column(:sign_date).of_type(:date).with_options(presence: true) }
    it { is_expected.to have_db_column(:unsigned_document).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:activity_seen).of_type(:boolean).with_options(presence: true, default: false) }
    it { is_expected.to have_db_column(:co_signer_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:paperwork_packet_type).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:signature_completion_date).of_type(:date).with_options(presence: true) }


    it { is_expected.to have_db_index(:co_signer_id) }
    it { is_expected.to have_db_index([:deleted_at]) }
    it { is_expected.to have_db_index(:document_id) }
    it { is_expected.to have_db_index(:paperwork_packet_id) }
    it { is_expected.to have_db_index(:paperwork_packet_type) }
    it { is_expected.to have_db_index(:requester_id) }
    it { is_expected.to have_db_index(:user_id) }

  end

  describe 'Associations' do
    it { is_expected.to belong_to(:user)}
    it { is_expected.to belong_to(:document)}
    it { is_expected.to belong_to(:requester).class_name('User')}
    it { is_expected.to belong_to(:co_signer).class_name('User')}
    it { is_expected.to belong_to(:paperwork_packet)}
    it { is_expected.to belong_to(:paperwork_packet_deleted).class_name('PaperworkPacket')}
  end

  describe 'Enums' do
    it { should define_enum_for(:paperwork_packet_type).with([:bulk, :individual]) }
  end

  describe 'scopes' do
    context 'missing_signed_documents' do
      it "should return missing_signed_documents if state is signed and co signer id is empty" do
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'signed', signed_document: nil)
        request.update!(updated_at: 10.minutes.ago)
        expect(PaperworkRequest.missing_signed_documents.count).to eq(0)
      end
      it "should return missing_signed_documents if state is all_signed and co signer id is not empty" do
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'all_signed', co_signer_id: user.id, signed_document: nil)
        request.update!(updated_at: 10.minutes.ago)
        expect(PaperworkRequest.missing_signed_documents.count).to eq(0)
      end
      it "should not return missing_signed_documents if state is all_signed and co signer id is empty" do
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'all_signed', signed_document: nil)
        request.update!(updated_at: 10.minutes.ago)
        expect(PaperworkRequest.missing_signed_documents.count).to eq(0)
      end
      it "should not return missing_signed_documents if state is signed and co signer id is not empty" do
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'signed', co_signer_id: user.id, signed_document: nil)
        expect(PaperworkRequest.missing_signed_documents.count).to eq(0)
      end
      it "should not return missing_signed_documents if signed_document is present" do
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'signed', co_signer_id: user.id)
        request.update!(updated_at: 10.minutes.ago)
        expect(PaperworkRequest.missing_signed_documents.count).to eq(0)
      end
    end

    context 'span_based_signed_documents' do
      it "should return span based signed document if date is between the given span" do
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'signed', signature_completion_date: Date.today)
        expect(PaperworkRequest.span_based_signed_documents(company.id, company.time.to_date, company.time.to_date).count).to eq(1)
      end
      it "should not return span based signed document if date is not between the given span" do
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'signed', signature_completion_date: 2.days.ago)
        expect(PaperworkRequest.span_based_signed_documents(company.id, 10.days.ago, 5.days.ago).count).to eq(0)
      end
      it "should not return span based signed document if date is between the given span but co_signer id is present" do
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'signed', signature_completion_date: 2.days.ago, co_signer_id: user.id)
        expect(PaperworkRequest.span_based_signed_documents(company.id, 3.days.ago, 1.days.from_now).count).to eq(0)
      end
      it "should return span based all_signed document if date is between the given span" do
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'all_signed', co_signer_id: user.id, signature_completion_date: Date.today)
        expect(PaperworkRequest.span_based_signed_documents(company.id, company.time.to_date, company.time.to_date).count).to eq(1)
      end
      it "should not return span based all_signed document if date is not between the given span" do
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'all_signed', co_signer_id: user.id, signature_completion_date: 2.days.ago)
        expect(PaperworkRequest.span_based_signed_documents(company.id, 10.days.ago, 5.days.ago).count).to eq(0)
      end
      it "should not return span based all_signed document if date is between the given span but co_signer id is not present" do
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'all_signed', signature_completion_date: 2.days.ago)
        expect(PaperworkRequest.span_based_signed_documents(company.id, 3.days.ago, 1.days.from_now).count).to eq(0)
      end
    end
  end

  describe 'callbacks' do
    before do
      @draft_response = (double('data', :data => {'signature_request_id' => 1, 'claim_url'=> 'url'}))
      # custom_fields = (double('data', :data => {'custom_fields' => ['']}))
      custom_fields = (double('data', :data => {'custom_fields' => [double('data', :data => '')]}))
      allow(HelloSign).to receive(:get_template).with(template_id: document_with_saved_template.paperwork_template.hellosign_template_id).and_return(custom_fields)
      allow(HelloSign).to receive(:create_embedded_unclaimed_draft)
        .with(test_mode: company.get_hellosign_test_mode,
          client_id: Sapling::Application::HELLOSIGN_CLIENT_ID,
          type: 'request_signature',
          subject: 'title',
          message: nil,
          requester_email_address: requester.email,
          :files => [nil],
          is_for_embedded_signing: 1,
          signers:  [{:email_address=>user.email, :name=>user.full_name, :role=>"employee", :order=>0}]).and_return(@draft_response)
    end
    
    context 'after validation #create_signature_request' do
      it 'should set hellosign_signature_request_id and hellosign_claim_url if template is not saved' do
        request = create(:paperwork_request, document_id: document.id, user_id: user.id, state: 'signed', requester_id: requester.id, signature_completion_date: Date.today)
        expect(request.hellosign_signature_request_id).to eq('1')
        expect(request.hellosign_claim_url).to eq('url')
      end

      it 'should set hellosign_signature_request_id and hellosign_claim_url if template is saved' do
        allow(HelloSign).to receive(:create_embedded_unclaimed_draft_with_template)
          .with(test_mode: company.get_hellosign_test_mode,
            client_id: Sapling::Application::HELLOSIGN_CLIENT_ID,
            template_id: document_with_saved_template.paperwork_template.hellosign_template_id,
            subject: 'title',
            message: nil,
            requester_email_address: requester.email,
            is_for_embedded_signing: 1,
            signers:  [{:email_address=>user.email, :name=>user.full_name, :role=>"employee", :order=>0}],
            custom_fields: {nil=>nil}).and_return(@draft_response)
        request = create(:paperwork_request, document_id: document_with_saved_template.id, user_id: user.id, state: 'signed', requester_id: requester.id)
        expect(request.hellosign_signature_request_id).to eq('1')
        expect(request.hellosign_claim_url).to eq('url')
      end

      it 'should set hellosign_signature_request_id and hellosign_claim_url if template is saved and paperwork_packet is present' do
        allow(HelloSign).to receive(:create_embedded_unclaimed_draft_with_template)
          .with(test_mode: company.get_hellosign_test_mode,
            client_id: Sapling::Application::HELLOSIGN_CLIENT_ID,
            template_ids: [document_with_saved_template.paperwork_template.hellosign_template_id],
            subject: 'title',
            message: nil,
            requester_email_address: requester.email,
            is_for_embedded_signing: 1,
            signers:  [{:email_address=>user.email, :name=>user.full_name, :role=>"employee", :order=>0}],
            custom_fields: {nil=>nil}).and_return(@draft_response)

        request = create(:paperwork_request, document_id: document_with_saved_template.id, user_id: user.id, state: 'signed', requester_id: requester.id, paperwork_packet: paperwork_packet, template_ids: [document_with_saved_template.paperwork_template.id])
        expect(request.hellosign_signature_request_id).to eq('1')
        expect(request.hellosign_claim_url).to eq('url')
      end
    end

    context 'after commit #set_signature_completion_date' do
      it 'should set signature_completion_date on create if request is signed' do
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'signed', requester_id: requester.id)
        request.set_signature_completion_date
        expect(request.signature_completion_date).to eq(Time.now.in_time_zone(request.user.company.time_zone).to_date)
      end

      it 'should not set signature_completion_date on create if requset is signed and template is_manager_representative' do
        document.paperwork_template.update(is_manager_representative: true)
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'signed', requester_id: requester.id)
        request.set_signature_completion_date
        expect(request.signature_completion_date).to eq(nil)
      end

       it 'should not set signature_completion_date on create if requset is signed and template representative_id is present' do
        document.paperwork_template.update(representative_id: 2)
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'signed', requester_id: requester.id)
        request.set_signature_completion_date
        expect(request.signature_completion_date).to eq(nil)
      end
      
      it 'should set signature_completion_date on create if request is all signed and co_signer_id is present' do
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'all_signed', co_signer_id: user.id, requester_id: requester.id)
        request.set_signature_completion_date
        expect(request.signature_completion_date).to eq(Time.now.in_time_zone(request.user.company.time_zone).to_date)
      end

      it 'should not set signature_completion_date on create if request is all signed and co_signer_id is not present' do
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'all_signed', requester_id: requester.id)
        request.set_signature_completion_date
        expect(request.signature_completion_date).to eq(nil)
      end

      it 'should set signature_completion_date on create if request is all signed and template is_manager_representative' do
        document.paperwork_template.update(is_manager_representative: true)
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'all_signed', co_signer_id: user.id, requester_id: requester.id)
        request.set_signature_completion_date
        expect(request.signature_completion_date).to eq(Time.now.in_time_zone(request.user.company.time_zone).to_date)
      end

      it 'should set signature_completion_date on create if request is all signed and template representative_id is present' do
        document.paperwork_template.update(representative_id: 2)
        request = create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'all_signed', co_signer_id: user.id, requester_id: requester.id)
        request.set_signature_completion_date
        expect(request.signature_completion_date).to eq(Time.now.in_time_zone(request.user.company.time_zone).to_date)
      end
    end

    context 'after destroy #remove_document' do
      let(:paperwork_request) { create(:paperwork_request, document_id: document.id, user_id: user.id, state: 'signed', requester_id: requester.id, signature_completion_date: Date.today) }

      it 'should delete document' do
        paperwork_request.remove_document
        expect(company.documents.count).to eq(1)
      end
    end
  end

  describe 'public methods' do
    context '#signed?' do
      it 'should return true if request is signed' do
        expect(request.signed?).to eq(true)
      end
      it 'should return false if request is all_signed' do
        expect(request1.signed?).to eq(false)
      end
    end

    context '#all_signed?' do
      it 'should return true if request is all_signed' do
        expect(request1.all_signed?).to eq(true)
      end
      it 'should return false if request is signed' do
        expect(request.all_signed?).to eq(false)
      end
    end

    context '#assigned?' do
      it 'should return true if request is assigned' do
        expect(request2.assigned?).to eq(true)
      end
      it 'should return false if request is signed' do
        expect(request.assigned?).to eq(false)
      end
    end

    context '#download_half_signed_document' do
      it 'should download half signed_document and update paperwork request' do
        draft_response = (double('data', :data => {'signature_request_id' => 1, 'claim_url'=> 'url'}))
        WebMock.allow_net_connect!
        allow(HelloSign).to receive(:signature_request_files)
          .with(signature_request_id: request.hellosign_signature_request_id).and_return(draft_response)
        response = request.download_half_signed_document
        expect(response.code).to eq(200)
        expect(request.unsigned_document).not_to eq(nil)
      end
    end

    context '#update_hellosign_signature_email' do
      it 'should return true after updating hellosign_signature_email' do
        allow_any_instance_of(PaperworkRequest).to receive(:get_hellosign_signature_id).with('abc@test.com').and_return(123)
        allow(HelloSign).to receive(:update_signature_request).with({signature_request_id: request.hellosign_signature_request_id,
                                          signature_id: 123 ,email_address: 'def@test.com'}).and_return(true)

        expect(request.update_hellosign_signature_email('abc@test.com', 'def@test.com')).to eq(true)
      end

      it 'should return false after updating hellosign_signature_email if hellosign_signature_id is not present' do
        allow_any_instance_of(PaperworkRequest).to receive(:get_hellosign_signature_id).with('abc@test.com').and_return(nil)
        allow(HelloSign).to receive(:update_signature_request)
          .with({signature_request_id: request.hellosign_signature_request_id, signature_id: 123 ,email_address: 'def@test.com'}).and_return(true)

        expect(request.update_hellosign_signature_email('abc@test.com', 'def@test.com')).to eq(nil)
      end
    end

    context '#get_signature_url' do
      it 'should return false if hellosign_signature_id is not present' do
        expect(request.get_signature_url('abc@test.com')).to eq(false)
      end

      it 'should return hellosign_signature_url if hellosign_signature_id is present' do
        draft_response = (double('data', :data => {'signatures' => [double('data', :data => {"signer_email_address" => "#{user.email}", "signature_id" => "123"})], "sign_url" => "test.com"}))
        allow(HelloSign).to receive(:get_signature_request).with(signature_request_id: request.hellosign_signature_request_id).and_return(draft_response)
        allow(HelloSign).to receive(:get_embedded_sign_url).with(signature_id: "123").and_return(draft_response)
       
        response = request.get_signature_url(user.email)
        expect(response).to eq("test.com")
      end
    end    
  end

  context 'user pending paperwork requests' do
    let!(:manager) { create(:user, company: company, role: User.roles[:employee])}
    let!(:user) { create(:user, state: :active, current_stage: :registered, company: company, manager:manager) }
    let!(:doc) { create(:document, company: company) }
    let!(:paperwork_request) { create(:paperwork_request, :request_skips_validate, document: doc, user: user, co_signer_id: manager.id, co_signer_type: PaperworkRequest.co_signer_types[:manager], state: "signed") }
    let!(:paperwork_template) { create(:paperwork_template, :template_skips_validate, document: doc, user: user, is_manager_representative: true, company: company) }

    it 'should get_count_of_templates_without_all_signed if all params are present' do
      expect(PaperworkRequest.template_without_all_signed(company, user.id, manager.id, 'all_signed').count).to eq(1)
    end
    
    it 'should not get_count_of_templates_without_all_signed if company is not present' do
      expect(PaperworkRequest.template_without_all_signed(nil, user.id, manager.id, 'all_signed')&.count).to eq(nil)
    end
    
    it 'should not get_count_of_templates_without_all_signed if user is not present' do
      expect(PaperworkRequest.template_without_all_signed(company, nil, manager.id, 'all_signed')&.count).to eq(nil)
    end
    it 'should not get_count_of_templates_without_all_signed if manager is not present' do
      expect(PaperworkRequest.template_without_all_signed(company, user.id, nil, 'all_signed')&.count).to eq(nil)
    end
    it 'should not get_count_of_templates_without_all_signed if state is not present' do
      expect(PaperworkRequest.template_without_all_signed(company, user.id, manager.id, nil)&.count).to eq(nil)
    end
  end
end

