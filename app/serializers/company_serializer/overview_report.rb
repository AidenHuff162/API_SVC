module CompanySerializer
  class OverviewReport < ActiveModel::Serializer
    attributes :date_format, :enabled_time_off, :surveys_enabled, :pto_paywall_feature_flag, 
    		:survey_paywall_feature_flag

  end
end
