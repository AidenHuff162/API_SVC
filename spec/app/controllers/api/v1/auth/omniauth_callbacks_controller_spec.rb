require 'rails_helper'

RSpec.describe Api::V1::Auth::OmniauthCallbacksController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:nick, company: company) }
  let!(:integration) { create(:integration, api_name: 'okta', company: company, identity_provider_sso_url: 'abc', saml_certificate: 'xyz')}
  let(:user_with_special_email) { create(:nick, :with_special_character_in_email, company: company) }
  let(:dbl) { double }

  before do
  	allow(controller).to receive(:current_company).and_return(company)
  end

  describe "#post consume_response" do

    # it "fetches user based on nameID sent whatever the case of nameID" do
    #   allow(dbl).to receive(:foo).with("NicK@test.com").and_return(user)
    #   expect(dbl.foo("NicK@test.com")).to eq(user)
    # end

    # it "fetches user based on nameID with special characters" do
    #   allow(dbl).to receive(:foo).with("Ni-cK@test.com").and_return(user_with_special_email)
    #   expect(dbl.foo("Ni-cK@test.com")).to eq(user_with_special_email)
    # end

    # it "does not fetch user having a different email from nameID" do
    #   allow(dbl).to receive(:foo).with("nickuser@test.com").and_return(nil)
    #   expect(dbl.foo("nickuser@test.com")).to eq(nil)
    # end

    context 'if saml credentials are not present' do
    	context 'for non ADFS integration' do
    		before do
    		  integration.update_columns(identity_provider_sso_url: nil, encrypted_saml_certificate: nil, encrypted_saml_certificate_iv: nil)
    		end
    		it 'should create logging and redirect' do
    			response = post :consume_saml_response
    			expect(company.loggings.reload.size).to eql(1)
    			expect(response).to redirect_to("https://#{company.app_domain}/#/login?error=user_does_not_exist&error_message=Missing+configurations")
    		end
    	end
    	context 'for ADFS integration' do
    		before do
    			integration.update_columns(api_name: 'active_directory_federation_services', encrypted_saml_certificate: nil, encrypted_saml_certificate_iv: nil)
    		end
    		it 'should create logging and redirect' do
    			response = post :consume_saml_response
    			expect(company.loggings.reload.size).to eql(1)
    			expect(response).to redirect_to("https://#{company.app_domain}/#/login?error=user_does_not_exist&error_message=Missing+configurations")
    		end
    	end
    end
    context 'if saml credentials are present' do
    	before do
        @saml_settings_double = double('saml_settings', idp_sso_target_url: 'http://www.sso.com',
                 idp_cert: 'certificate131312', name_identifier_format: 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress')
        allow(controller).to receive(:saml_settings).and_return(@saml_settings_double)
    	end

    	context 'response is valid' do
    		before do
	    		response = double('settings=' => '@saml_settings_double')
	    		response.stub(:is_valid?){ true }
	    		allow(OneLogin::RubySaml::Response).to receive(:new).and_return(response) 
	    		allow(User).to receive(:from_saml_response).and_return(user) 
          auth_params = {"auth_token"=>ENV['OMNIAUTH_TOKEN'], "client_id"=>"#{ENV['OMNIAUTH_CLINET_ID']}", "uid"=>user.id, "expiry"=>1571121425, "config"=>nil}
      		allow(controller).to receive(:create_auth_params).and_return(auth_params)
	    	end

	    	it 'should sign in user' do
	    		response = post :consume_saml_response
          expect(response).to redirect_to("https://#{company.app_domain}/#/login?auth_token=#{ENV['OMNIAUTH_TOKEN']}&client_id=#{ENV['OMNIAUTH_CLINET_ID']}&config=&expiry=1571121425&uid=#{user.id}&sapling_auth=true")
	    	end

        it 'should not sign in user if class name is not user' do
          user.class.stub(:name) {'Muser'}
          response = post :consume_saml_response
          expect(company.loggings.reload.size).to eql(1)
          expect(response).to redirect_to("https://#{company.app_domain}/#/login?error=user_does_not_exist&error_message=#{user.id}")
        end
    	end

      context 'response is valid' do
        before do
          response = double('settings=' => '@saml_settings_double')
          response.stub(:is_valid?){ false }
          allow(OneLogin::RubySaml::Response).to receive(:new).and_return(response) 
          allow(User).to receive(:from_saml_response).and_return(user) 
        end

        it 'should not sign in user' do
          response = post :consume_saml_response
          expect(company.loggings.reload.size).to eql(1)
          expect(response).to redirect_to("https://#{company.app_domain}/#/login?error=user_does_not_exist&error_message=User+doesn%27t+exist%21")
        end
      end
    end
  end

end
