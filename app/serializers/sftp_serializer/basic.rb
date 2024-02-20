module SftpSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :name, :host_url, :updater_full_name, :updated_at
  end
end
