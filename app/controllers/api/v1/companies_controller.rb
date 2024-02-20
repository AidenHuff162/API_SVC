module Api
  module V1
    class CompaniesController < ApiController
      before_action :require_company!
      before_action :authenticate_user!, except: :auth_current

      before_action only: [:current] do
        ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab])
      end
      rescue_from CanCan::AccessDenied do |exception|
        render body: Sapling::Application::EMPTY_BODY, status: 204 if params[:sub_tab].present?
      end

      def current
        company_filter
      end

      def auth_current
        respond_with current_company, serializer: CompanySerializer::LogIn, include: '**'
      end

      private
      def company_filter

        if params[:user_profile_company_serializer].present?
          respond_with current_company, serializer: CompanySerializer::UserProfile, include: '**'
        elsif params[:user_info_company_serializer].present?
          respond_with current_company, serializer: CompanySerializer::UserInfo, include: '**'
        elsif params[:dashboard_company_serializer].present?
          respond_with current_company, serializer: CompanySerializer::Full, scope: {current_user: current_user}, include: '**'
        elsif params[:preboard_welcome_company_serializer].present?
          respond_with current_company, serializer: CompanySerializer::PreboardWelcome, include: '**'
        elsif params[:preboard_story_company_serializer].present?
          respond_with current_company, serializer: CompanySerializer::PreboardStory, include: '**'
        elsif params[:preboard_about_company_serializer].present?
          respond_with current_company, serializer: CompanySerializer::PreboardAbout, include: '**'
        elsif params[:company_landing_company_serializer].present?
          respond_with current_company, serializer: CompanySerializer::Landing, include: '**'
        elsif params[:check_jira_integration].present?
          respond_with current_company, serializer: CompanySerializer::Basic, scope: { check_jira_integration: true }, include: '**'
        elsif params[:shareable_org_chart].present?
          respond_with current_company, serializer: CompanySerializer::Basic, scope: { shareable_org_chart: true }, include: '**'
        elsif params[:integration_serializer].present?
          respond_with current_company, serializer: CompanySerializer::IntegrationPage, scope: {current_user: current_user}
        elsif params[:webhook_serializer].present?
          respond_with current_company, serializer: CompanySerializer::WebhookDialog
        elsif params[:webhook_page_serializer].present?
          respond_with current_company, serializer: CompanySerializer::WebhookPage, token_visible: false
        elsif params[:api_serializer].present?
          respond_with current_company, serializer: CompanySerializer::ApiPage
        elsif params[:show_inbox].present? && !Rails.env.test?
          respond_with current_company, serializer: CompanySerializer::Basic, include: '**'
        else
          respond_with current_company, serializer: CompanySerializer::Basic, include: '**'
        end
      end
    end
  end
end
