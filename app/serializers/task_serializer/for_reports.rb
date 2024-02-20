module TaskSerializer
  class ForReports < ActiveModel::Serializer
    attributes :id, :name, :workstream_id, :position, :workspace_id
    
    def name
      Nokogiri::HTML(object.name).xpath("//*[p]").first.content rescue " "
    end

  end
end
