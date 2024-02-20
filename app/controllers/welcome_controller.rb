class WelcomeController < ApplicationController
  before_action :find_subdomain, except: :health
  def index
  	unless @subdomain_exist
  		redirect_to "https://www.trysapling.com/"
  	end
  end

  def check_subdomain
    if @subdomain_exist
      render json: {status: 200}
    else
      render json: {status: 404}
    end
  end

  def health
    data = File.read(".app-version")
    service = request.path.include?("admin") ? 'Admin' : 'API'
    respond_to do |format|
      format.html {redirect_to "/"}
      format.json   {render json: {service: service,version: data}}
    end
  end

  def get_orgchart
    if @subdomain_exist && params[:token].present?
      current_company = Company.where(subdomain: request.subdomain).where(token: params[:token]).take
    end
    if current_company.present? && current_company.enabled_org_chart
      tree = User.get_organization_tree(current_company)
      render json: {org_root_present: current_company.organization_root.present?, tree: tree}.to_json, status: 200
    else
      render json: {org_root_present: false, token_status: 'expired', tree: {}}.to_json, status: 200
    end
  end

  private

  def find_subdomain
    @subdomain_exist = Company.exists?(subdomain: request.subdomain, account_state: 'active') if request.subdomain.present?
  end

end
