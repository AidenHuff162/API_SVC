module Api
  module V1
    module Admin
      class SftpsController < BaseController
        authorize_resource
        load_resource except: [:paginated, :create]
        before_action :check_sftp_feature_flag

        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 403
        end

        def index 
          collection = SftpsCollection.new(params.merge(company_id: current_company.id))
          respond_with collection.results, each_serializer: SftpSerializer::Simple
        end

        def paginated
          collection = SftpsCollection.new(paginated_params)
          results = collection.results
          render json: {
            recordsTotal: results.count,
            data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: SftpSerializer::Basic)
          }
        end

        def create
          save_respond_with_form
        end
        
        def destroy
          @sftp.destroy!
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def show
          respond_with @sftp, serializer: SftpSerializer::Full, company: current_company
        end

        def update
          save_respond_with_form
        end

        def duplicate
          new_sftp = @sftp.dup
          new_sftp.public_key = @sftp.upload_public_key(@sftp.public_key) if @sftp.public_key?
          new_sftp.name = DuplicateNameService.call(new_sftp.name, current_company.sftps)
          new_sftp.save!
        end

        def test
          render json: {
            test_response: SftpService::SendFileToSftp.new(@sftp, nil, true).perform
          }
        end

        private

        def save_respond_with_form
          form = SftpForm.new(sftp_params) 
          form.save!
          respond_with form, serializer: SftpSerializer::Basic, company: current_company
        end

        def sftp_params
          params.permit(:name, :host_url, :authentication_key_type, :user_name, :password, :port, :folder_path, :updated_by_id, :id).merge(public_key: params[:public_key], company_id: current_company.id)
        end

        def paginated_params
          page = (params[:start].to_i / params[:length].to_i) + 1 rescue 1
          column_map = { '0': 'name', '2': 'updated_at'}
          sort_column = column_map[params['order']['0']['column'].to_sym] rescue nil
          sort_order = params['order']['0']['dir'] rescue nil
          params.merge(
            company_id: current_company.id,
            page: page,
            per_page: params[:length].to_i,
            order_column: sort_column,
            sort_order: sort_order
          )
        end

        def check_sftp_feature_flag
          raise CanCan::AccessDenied unless current_company.sftp_feature_flag
        end
      end     
    end
  end
end
