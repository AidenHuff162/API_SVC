require 'rails_helper'

RSpec.describe AdminUsers::SessionsController, type: :controller do
  before(:each) do     
    @request.host = "#{ENV['DEFAULT_HOST']}:3000"           
    @admin_user = create(:admin_user)
    @request.env["devise.mapping"] = Devise.mappings[:admin_user]    
    @params = {utf8: "✓", _method: "post", user_email:"#{@admin_user.email}", admin_user: {email:"#{@admin_user.email}", password: "secret123$", password_confirmation: "secret123$", reset_password_token: "SCfhRMnJ73KHUzCGW7Qk"}, commit: "create session", controller: "admin_users/sessions", action: "create"}      
  end

  context 'if redirect_id presense and it is 1' do
    it 'should redirect to login' do
      @params[:redirect_id] = 1
      response = post :create, params: @params, format: :json
      expect(response).to redirect_to('/admin/login')
    end
  end
 
  context 'if redirect_id presense but it is not 1' do
    it 'should redirect to login' do
      @params[:redirect_id] = 0
      @params[:user_email] = @admin_user.email
      response = post :create, params: @params
      expect(response).to have_http_status(:success)
    end
  end

  context 'if redirect_id not presense' do
    before do
      @admin_user.otp_required_for_login = false
      @admin_user.save()
    end
    it 'with right email should redirect to dashboard' do
      @params[:user_email] = @admin_user.email
      response = post :create, params: @params
      expect(response).to redirect_to('/admin/dashboard')
    end
  end

  context 'if otp required and otp attempt presense' do
    before do
      @admin_user.otp_required_for_login = true
      @admin_user.otp_attempt = 0
      @admin_user.save()
      allow(controller).to receive(:sign_in_params).and_return({"email":"#{@admin_user.email}","password":"secret123$", "otp_attempt":1})
    end
    it 'should redirect to login' do
      response = post :create, params: @params
      expect(response).to have_http_status(:success)
    end      
  end
 
  context 'if account with inactive user ' do
    before do
      @admin_user.deactivate!
      @admin_user.save!()
    end
    it 'should redirect to login' do
      @params[:user_email] = @admin_user.email
      response = post :create, params: @params
      expect(response).to redirect_to('/admin/login')
    end
  end  

  context 'if account with invalid email ' do
    it 'should redirect to login' do
      @params[:user_email] = "abc@q.c"
      @params[:admin_user][:email] = "abc@q.c"
      response = post :create, params: @params
      expect(response).to redirect_to('/admin/login')
    end
  end

  context 'if actived account with invalid password' do
    before do
      @admin_user.password = 'abc'
      @admin_user.save!()
    end
    it 'should redirect to login' do
      @params[:user_email] = @admin_user.email
      response = post :create, params: @params
      expect(response).to redirect_to('/admin/login')
    end
  end

  context 'if update password ' do
    it 'with password equal ' do
      @params[:action]= "update_password"
      @request.env['HTTP_REFERER'] = '/admin_users/sessions/update_password'
      response = post :update_password, params: @params
      expect(response).to have_http_status(:success)
    end
  end

  context 'if update password ' do
    it 'with password not equal ' do
      @params[:action]= "update_password"
      @params[:admin_user][:email]= "test@email.com"
      @request.env['HTTP_REFERER'] = '/admin_users/sessions/update_password'
      response = post :update_password, params: @params
      expect(response).to redirect_to('/admin_users/sessions/update_password')
    end
  end
  
  context 'if change password ' do
    it 'with right token ' do
      @params[:admin_user] = {eamil:"#{@admin_user.email}", password: "secret123$", password_confirmation: "secret123$", reset_password_token: "SCfhRMnJ73KHUzCGW7Qk"}
      @params[:action]= "change_password_form"
      @params[:_method]= "get"
      @params[:token]= @admin_user.email_verification_token
      @request.env['HTTP_REFERER'] = "/admin/admin_users/sessions/change_password_form/#{@admin_user.email_verification_token}"
      response = get :change_password_form, params: @params
      expect(response).to  have_http_status(:success)
    end
  end

  context 'if change password ' do
    it 'with wrong token ' do
      @params[:admin_user] = {eamil:"#{@admin_user.email}", password: "secret123$", password_confirmation: "secret123$", reset_password_token: "SCfhRMnJ73KHUzCGW7Qk"}    
      @params[:action]= "change_password_form"
      @params[:_method]= "get"
      @params[:token]= "abc"
      @request.env['HTTP_REFERER'] = "/admin/admin_users/sessions/change_password_form/"
      response = get :change_password_form, params: @params
      expect(response).to have_http_status(:success)
    end
  end

  context 'if account actived with right pass' do
    before do
      @admin_user.activate
      @admin_user.save(:validate => true)
      sign_in @admin_user
    end
    it 'should redirect to dashboard' do
      response = post :create, params: @params
      expect(response).to redirect_to('/admin/dashboard')                
    end
  end 
  
  context 'admin user session destroy test' do 
    before do
      sign_in @admin_user
    end
    it 'should destroy the cookie' do 
      @params[:action]= "destroy"
      @params[:_method]= "get"
      response = get :destroy, params: @params
      expect(response).to have_http_status(302)
    end
  end
end

