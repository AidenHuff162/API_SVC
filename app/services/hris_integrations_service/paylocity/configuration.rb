class HrisIntegrationsService::Paylocity::Configuration

  def random_aes_key; (@random_aes_key || raise("KEYNOT FOUND")); end
  def random_aes_iv; (@random_aes_iv || raise("IV NOT FOUND")); end

  def cipher
    @cipher ||= begin
      c = OpenSSL::Cipher::AES256.new(:CBC)
      c.encrypt
      @random_aes_key = c.random_key
      @random_aes_iv = c.random_iv
      c.padding = 1
      c
    end
  end

  def get_pub_key_from_xml(key_xml)
    chilk = Chilkat::CkPublicKey.new()
    chilk.put_Utf8(true)
    chilk.LoadXml(key_xml)
    chilk.getPem(true)
  end

  def encrypt_data(data)
    @random_aes_key = cipher.random_key
    @random_aes_iv = cipher.random_iv
    encrypted = cipher.update(data)
    encrypted << cipher.final
    encrypted
  end

  def encode_data(data)
    Base64.strict_encode64(encrypt_data(data))
  end

  def encrypt_key(key, rsa_key)
    rsa = OpenSSL::PKey::RSA.new rsa_key
    rsa.public_encrypt(key)
  end

  def generate_options(req_json, signature_token_xml, client_id, client_secret)
    encoded_content = encode_data(req_json)
    signature_token = get_pub_key_from_xml(signature_token_xml)
    options = get_basic_options(client_id, client_secret)

    options[:body] = {
        secureContent: {
          key: Base64.strict_encode64(encrypt_key(random_aes_key, signature_token)),
          iv: Base64.strict_encode64(random_aes_iv),
          content: encoded_content
        }
      }.to_json

    options
  end

  def get_basic_options(client_id, client_secret)
    options = {
      headers: {
        'Content-Type'=> 'application/json',
        'Authorization'=> 'Bearer ' + retrieve_bearer_token(client_id, client_secret).to_s
      }
    }
  end

  def retrieve_bearer_token(client_id, client_secret)
    require 'uri'
    require 'net/http'
    url = nil

    if Rails.env.production?
      url = URI("https://api.paylocity.com/IdentityServer/connect/token")

    else
      url = URI("https://apisandbox.paylocity.com/IdentityServer/connect/token")
    end

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request["content-type"] = 'application/x-www-form-urlencoded'
    request["authorization"] = 'Basic ' + Base64.strict_encode64(client_id + ':' + client_secret)
    request["cache-control"] = 'no-cache'
    request["postman-token"] = '8d38baef-4cfc-8e9c-6232-54265d806710'
    request.body = "scope=WebLinkAPI&grant_type=client_credentials"


    response = http.request(request)
    JSON.parse(response.read_body)["access_token"]
  end
end