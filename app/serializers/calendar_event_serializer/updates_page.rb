module CalendarEventSerializer
  class UpdatesPage < ActiveModel::Serializer
    attributes :event_type, :event_start_date, :eventable_type, :year

    belongs_to :eventable, polymorphic: true

    def self.serializer_for(model, options)
      return TaskUserConnectionSerializer::Base if model.class.name == 'TaskUserConnection'
      return UserSerializer::NewArrival if model.class.name == 'User'
      super
    end    
  end
end
