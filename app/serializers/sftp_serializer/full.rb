module SftpSerializer
  class Full < ActiveModel::Serializer
    attributes :name, :host_url, :authentication_key_type, :user_name, :password, :port, :folder_path, :id
    has_one :public_key

    def password
      object.password&.gsub(/.(?=.{4,}$)/,'*')
    end
  end
end
