module Api
  module V1
    class AddressController < ApiController
      before_action :require_company!

      def countries_index
        respond_with Country.ascending(:name), each_serializer: CountrySerializer::Basic
      end

      def states_index
        if params[:flatfile_sates]
          respond_with State.ascending(:name), each_serializer: StateSerializer::WithNameKey
        else
          respond_with AddressManager::CountryStatesRetriever.call(current_company, params[:country_id])
        end
      end
    end
  end
end