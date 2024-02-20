module PtoPolicySerializer
	class MinimalData < ActiveModel::Serializer
		attributes :id, :name, :unit, :unlimited_policy

    def unit
      if object.tracking_unit == 'daily_policy'
        "day(s)"
      else
        "hour(s)"
      end
    end
		
	end
end