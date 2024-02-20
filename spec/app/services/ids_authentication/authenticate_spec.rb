require 'rails_helper'

RSpec.describe IdentityServer::Authenticator do
  let(:company) { create(:company) }
  let!(:user) { create(:user, company: company, email: 'dilshad.mus+123@kallidus.com') }
  let(:code) { 'sbwcbX6fzG6g6KkMk8e_qwKIsmu4JINMvKloVk1F2UM' }
  let(:response) { ActionDispatch::Response.new }
  let(:access_token) { ids_token.access_token }

  before { WebMock.disable_net_connect! }

  describe 'authenticatate' do
    # describe 'get_user_from_ids' do
    #   subject(:get_user_from_ids) do
    #     described_class.new(company, response).get_user_from_ids(code, code)
    #   end

    #   let(:user_response) { { status: 200, body: { email: user.email }.to_json } }
    #   let(:token_response) do
    #     OpenStruct.new({ status: 200, body: { access_token: 'give_access_token',
    #                                           id_token: 'give_id_token',
    #                                           refresh_token: 'give_refresh_token',
    #                                           expires_in: 3600 }.to_json })
    #   end

    #   before do
    #     stub_request(:post, 'https://tenant-six.suite.int.kallidusazure.com/identity/connect/token')
    #       .to_return(token_response)
    #     stub_request(:get, 'https://tenant-six.suite.int.kallidusazure.com/identity/connect/userinfo')
    #       .to_return(user_response)
    #   end

    #   it 'returns user' do
    #     expect(get_user_from_ids.email).to eq(user.email)
    #   end

    #   it 'creates ids-token' do
    #     get_user_from_ids
    #     expect(user.reload.ids_tokens.first.present?).to eq(true)
    #   end

    #   it 'updates response headers' do
    #     get_user_from_ids
    #     expect(JsonWebToken.decode(response['access-token'])[:access_token]).to eq('give_access_token')
    #     expect(response['expiry']).to eq(3600)
    #   end

    #   context 'with invalid code and code verfier' do
    #     let(:token_response) { OpenStruct.new({ status: 400, body: '' }) }

    #     it 'returns nil' do
    #       expect(get_user_from_ids).to be_nil
    #     end
    #   end

    #   context 'with invalid access_token' do
    #     let(:token_response) do
    #       OpenStruct.new({ status: 200, body: { access_token: 'give_access_token',
    #                                             id_token: 'give_id_token',
    #                                             refresh_token: 'give_refresh_token',
    #                                             expires_in: 3600 }.to_json })
    #     end
    #     let(:token_response) { OpenStruct.new({ status: 400, body: '' }) }

    #     it 'returns nil' do
    #       expect(get_user_from_ids).to be_nil
    #     end

    #     it 'destroys ids-token' do
    #       get_user_from_ids
    #       expect(user.reload.ids_tokens.first.present?).to eq(false)
    #     end

    #     it 'updates response headers to nil' do
    #       get_user_from_ids
    #       expect(response['access-token']).to be_nil
    #       expect(response['expiry']).to be_nil
    #     end
    #   end
    # end

    # describe 'get_user_with_request_headers' do
    #   subject(:get_user_with_request_headers) do
    #     described_class.new(company, response).get_user_with_request_headers(access_token)
    #   end

    #   let!(:ids_token) { create(:ids_token, user: user, company: company) }
    #   let(:user_response) { { status: 200, body: { email: user.email }.to_json } }
    #   let(:token_response) do
    #     OpenStruct.new({ status: 200, body: { access_token: 'give_access_token',
    #                                           id_token: 'give_id_token',
    #                                           refresh_token: 'give_refresh_token',
    #                                           expires_in: 3600 }.to_json })
    #   end

    #   before do
    #     stub_request(:post, 'https://tenant-six.suite.int.kallidusazure.com/identity/connect/token')
    #       .to_return(token_response)
    #     stub_request(:get, 'https://tenant-six.suite.int.kallidusazure.com/identity/connect/userinfo')
    #       .to_return(user_response)
    #   end

    #   it 'returns user' do
    #     expect(get_user_with_request_headers.email).to eq(user.email)
    #   end

    #   context 'with access token which is about to expire' do
    #     context 'with valid refresh token' do
    #       let(:token_response) do
    #         OpenStruct.new({ status: 200, body: { access_token: 'give_access_token_2',
    #                                               id_token: 'give_id_token_2',
    #                                               refresh_token: 'give_refresh_token_2',
    #                                               expires_in: 3600 }.to_json })
    #       end

    #       it 'returns user' do
    #         user.ids_tokens.first.update(access_token_expiry: ids_token.access_token_expiry - 30.minutes)
    #         expect(get_user_with_request_headers.email).to eq(user.email)
    #       end

    #       it 'updates ids tokens' do
    #         user.ids_tokens.first.update(access_token_expiry: ids_token.access_token_expiry - 30.minutes)
    #         get_user_with_request_headers
    #         user.reload
    #         expect(user.ids_tokens.first.old_access_token).to eq('give_access_token')
    #         expect(user.ids_tokens.first.access_token).to eq('give_access_token_2')
    #         expect(user.ids_tokens.first.id_token).to eq('give_id_token_2')
    #         expect(user.ids_tokens.first.refresh_token).to eq('give_refresh_token_2')
    #       end

    #       it 'updates response headers' do
    #         user.ids_tokens.first.update(access_token_expiry: ids_token.access_token_expiry - 30.minutes)
    #         get_user_with_request_headers
    #         expect(JsonWebToken.decode(response['access-token'])[:access_token]).to eq('give_access_token_2')
    #         expect(response['expiry']).to eq(3600)
    #       end
    #     end

    #     context 'with invalid refresh token' do
    #       let(:token_response) do
    #         OpenStruct.new({ status: 400, body: {}.to_json })
    #       end
    #       let(:user_response) { { status: 400, body: {}.to_json } }

    #       it 'returns nil' do
    #         user.ids_tokens.first.update(access_token_expiry: ids_token.access_token_expiry - 30.minutes)
    #         expect(get_user_with_request_headers).to be_nil
    #       end

    #       it 'destroys ids-token' do
    #         user.ids_tokens.first.update(access_token_expiry: ids_token.access_token_expiry - 30.minutes)
    #         get_user_with_request_headers
    #         expect(user.reload.ids_tokens.first.present?).to eq(false)
    #       end

    #       it 'updates response headers to nil' do
    #         user.ids_tokens.first.update(access_token_expiry: ids_token.access_token_expiry - 30.minutes)
    #         get_user_with_request_headers
    #         expect(response['access-token']).to be_nil
    #         expect(response['expiry']).to be_nil
    #       end
    #     end

    #     context 'with invalid access token' do
    #       let(:token_response) do
    #         OpenStruct.new({ status: 200, body: { access_token: 'give_access_token_2',
    #                                               id_token: 'give_id_token_2',
    #                                               refresh_token: 'give_refresh_token_2',
    #                                               expires_in: 3600 }.to_json })
    #       end
    #       let(:user_response) { { status: 400, body: {}.to_json } }

    #       it 'returns nil' do
    #         user.ids_tokens.first.update(access_token_expiry: ids_token.access_token_expiry - 30.minutes)
    #         expect(get_user_with_request_headers).to be_nil
    #       end

    #       it 'destroys ids-token' do
    #         user.ids_tokens.first.update(access_token_expiry: ids_token.access_token_expiry - 30.minutes)
    #         get_user_with_request_headers
    #         expect(user.reload.ids_tokens.first.present?).to eq(false)
    #       end

    #       it 'updates response headers to nil' do
    #         user.ids_tokens.first.update(access_token_expiry: ids_token.access_token_expiry - 30.minutes)
    #         get_user_with_request_headers
    #         expect(response['access-token']).to be_nil
    #         expect(response['expiry']).to be_nil
    #       end
    #     end
    #   end

    #   context 'with expired access token' do
    #     it 'return nil' do
    #       user.ids_tokens.first.update(access_token_expiry: DateTime.now)
    #       expect(get_user_with_request_headers).to be_nil
    #     end

    #     it 'destroys ids-token' do
    #       user.ids_tokens.first.update(access_token_expiry: DateTime.now)
    #       get_user_with_request_headers
    #       expect(user.reload.ids_tokens.first.present?).to eq(false)
    #     end

    #     it 'updates response headers to nil' do
    #       user.ids_tokens.first.update(access_token_expiry: DateTime.now)
    #       get_user_with_request_headers
    #       expect(response['access-token']).to be_nil
    #       expect(response['expiry']).to be_nil
    #     end
    #   end
    # end
  end
end
