module Api
  module V1
    module Admin
      class ApiKeysController < BaseController
        load_and_authorize_resource except: [:index, :generate_api_key]
        authorize_resource only: [:index, :generate_api_key]

        def generate_api_key
          generated_api_key = { key: JsonWebToken.encode({ company_id: current_company.id, Time: Time.now.to_i}, nil, true) }
          respond_with generated_api_key.to_json
        end

        def index
          respond_with current_company.general_api_keys, each_serializer: ApiKeySerializer::Basic
        end

        def create
          @api_key.save!
          respond_with @api_key, serializer: ApiKeySerializer::Basic
        end

        def destroy
          @api_key.destroy!
          head :no_content
        end

        private

        def api_key_params
          params.merge(company_id: current_company.id, edited_by_id: current_user.id)
                .permit(:id, :edited_by_id, :name, :company_id, :key, :auto_renew, selected_api_key_fields: {})
        end
      end
    end
  end
end
