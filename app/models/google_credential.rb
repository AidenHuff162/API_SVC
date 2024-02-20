class GoogleCredential < ApplicationRecord
  belongs_to :credentialable, polymorphic: true
end
