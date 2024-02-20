module PtoRequestSerializer
  class UpdatesPage < ActiveModel::Serializer
    attributes :begin_date, :end_date, :status, :partial_day_included, :return_date

    def return_date
      object.get_return_day(true)
    end
  end
end
