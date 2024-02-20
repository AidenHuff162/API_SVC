module PaperworkRequestSerializer
  class WithCosigner < Full
    has_one :co_signer, serializer: UserSerializer::Basic
  end
end
