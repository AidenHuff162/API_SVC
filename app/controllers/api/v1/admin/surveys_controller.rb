module Api
  module V1
    module Admin
      class SurveysController < BaseController

        load_and_authorize_resource

        def index
          collection = SurveysCollection.new(survey_params)
          respond_with collection.results.order(:id), each_serializer: SurveySerializer::Base
        end

        def show          
          respond_with @survey, serializer: SurveySerializer::Base
        end

        private

        def survey_params
          params.permit().merge(company_id: current_company.id)
        end

      end
    end
  end
end
