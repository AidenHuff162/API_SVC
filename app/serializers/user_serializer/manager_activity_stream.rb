module UserSerializer
  class ManagerActivityStream < Base
    attributes :id, :type, :created_at

    def type
      'collect_from'
    end
  end
end
