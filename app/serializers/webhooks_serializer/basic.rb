module WebhooksSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :state, :event
    
    def event
      object.event.gsub("_"," ").titlecase
    end

    def state
      object.state.gsub("_"," ")
    end 
  end
end
