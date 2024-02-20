class Api::V1::Admin::ActiveAdmin::AdminRequestsController < ActionController::Base
  protect_from_forgery with: :exception, prepend: true, if: Proc.new { |c| c.request.format != 'application/json' }
  protect_from_forgery with: :null_session, prepend: true, if: Proc.new { |c| c.request.format == 'application/json' }

  before_action :authenticate_active_admin
  after_action :update_access_token
  include SetAdminAccessToken

  def load_company_team_and_locations
    comp_id = params[:comp_id]
    if comp_id.present?
      comp = Company.find(comp_id)
      company_teams = comp.teams.order('LOWER(name) ASC')
      locations = comp.locations.order('LOWER(name) ASC')
    end
    render json: {"company_teams"=>company_teams,'locations'=>locations}
  end

  def document_url
    document = ActiveAdmin::GetDocument.new(params[:paperwork_request_entry_id]).perform()
    render json: document
  end
      
  def delete_paperwork_request
    @paperwork_request = PaperworkRequest.find(params[:doc_id])	          
    @paperwork_request.destroy!          
    redirect_to admin_user_path(params[:user_id])
  end
  
  private 

  def authenticate_active_admin
    unless ActiveAdmin::ValidateAccess.new(params[:access_token], current_admin_user).check_validity?
      render json: { error:'Unauthorized Access' }, status: :unauthorized
    end
  end

  def update_access_token
    set_access_token_on_front_end(current_admin_user)
  end
end
