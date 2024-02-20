module LocationSerializer
  class Group < ActiveModel::Serializer
    type :location
    attributes :id, :name, :active_users, :inactive_users

    def active_users
      User.where(company_id: object['company_id'], location_id: object['id'], state: 'active').count
    end

    def inactive_users
      User.where(company_id: object['company_id'], location_id: object['id'], state: 'inactive').count
    end

    def read_attribute_for_serialization(attr)
      if object.key? attr.to_s
        object[attr.to_s]
      else
        self.send(attr) rescue nil
      end
    end
  end
end
