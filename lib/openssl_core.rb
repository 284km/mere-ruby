module OpenSSL
  class OpenSSLError
    def errors; @errors || []; end
  end
  # The portable ASN.1 implementation raises Ruby exceptions and has no native
  # error queue. Loading the native provider replaces this with ERR_get_error.
  def self.errors
    []
  end
end
