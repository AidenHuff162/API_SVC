class String
  
  def pack_encryption_key(bytes)
    return if self.length < bytes

    self.bytes[0..(bytes - 1)].pack('c' * bytes)
  end

end
