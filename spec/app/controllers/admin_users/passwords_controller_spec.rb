require 'rails_helper'

RSpec.describe AdminUsers::PasswordsController, type: :controller do
  include Devise::TestHelpers
	describe '#update' do
  	before(:each) do
  	  @admin_user = create(:admin_user)
  	  @params = {params: {utf8: "✓", _method: "put", admin_user: {password: "hahahaha", password_confirmation: "hahahaha", reset_password_token: "SCfhRMnJ73KHUzCGW7Qk"}, commit: "Change my password", controller: "admin_users/passwords", action: "update"}}
  	  @request.env["devise.mapping"] = Devise.mappings[:admin_user]
  	  allow(AdminUser).to receive(:reset_password_by_token).and_return(@admin_user)
  	end
  	context 'password updation with valid arugments' do
  		it 'updates the password to new password' do
  			current_password = @admin_user.encrypted_password
  			post :update, @params
  			expect(@admin_user.reload.encrypted_password).to_not eq(current_password)
  		end
  		context 'otp required' do
  			it 'renders qr_template' do
  				response = post :update, @params
  				expect(response).to render_template('admin_users/sessions/qr_template')
  			end
  		end
  		context 'otp not required' do
  			before do
  				@admin_user.update_column(:otp_required_for_login, false)
  			end
  			it 'redirects_to new_user_session_path' do
  				response = post :update, @params
  				expect(response).to redirect_to('/admin/login')
  			end
  			it 'logs admin user in' do
  				post :update, @params
  				expect(@admin_user.reload.last_sign_in_at).to_not eq(nil)
  			end
  		end
  	end
  	context 'password not matching' do
  		it 'should redirect_to back' do
  			@request.env['HTTP_REFERER'] = '/admin/password/edit'
  			@params[:params][:admin_user][:password_confirmation] = 'mismatchpassword'
  			response = post :update, @params
  			expect(response).to redirect_to('/admin/password/edit')
  		end
  	end
  	context 'unable to fetch admin_user' do
  		before do
  			allow(AdminUser).to receive(:reset_password_by_token).and_return(nil)
  		end
  		it 'should redirect_to back' do
  			@request.env['HTTP_REFERER'] = '/admin/password/edit'
  			response = post :update, @params
  			expect(response).to redirect_to('/admin/password/edit')
  		end
  	end
  end
end
