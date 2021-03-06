require "base64"
require "json"
require "time"
require 'cgi'
require 'openssl'

module AliyunOpenSearch
  class Base
    attr_reader :basic_params, :base_url

    class << self
      attr_accessor :request_method
    end

    # @param [Hash] {:endpoint => opensearch的域名, :access_key_id, :access_key_secret}
    def initialize(option)
      @option = option
      @basic_params = basic_params

      @base_url = "#{@option[:endpoint]}/search"
    end

    def uri(special_base_url = nil, params)
      encoded_params = params.inject([]) do |arr, (k, v)|
        arr << "#{k}=#{Base.escape(v)}"
      end.join("&")

      url = (special_base_url || base_url) + "?" + encoded_params
      Rails.logger.info url if defined?(Rails)

      URI(url)
    end

    def self.request_method
      @request_method ||= "GET"
    end

    def signature(params)
      params = params.sort_by {|k, _v| k.to_s}
                 .map do |arr|
        str = if arr[1].is_a?(String) || arr[1].is_a?(Fixnum)
                arr[1].to_s
              else
                arr[1].to_json
              end

        "#{arr[0]}=#{Base.escape(str)}"
      end.join("&")

      Base64.encode64(
        OpenSSL::HMAC.digest(
          OpenSSL::Digest.new("sha1"),
          "#{@option[:access_key_secret]}&",
          self.class.request_method + "&" + CGI.escape("/") + "&" + Base.escape(params)
        )
      ).strip
    end

    def basic_params
      {
        "Version" => "v2",
        "AccessKeyId" => @option[:access_key_id],
        "SignatureMethod" => "HMAC-SHA1",
        "Timestamp" => Time.now.utc.iso8601,
        "SignatureVersion" => "1.0",
        "SignatureNonce" => self.class.signature_nonce
      }
    end

    def self.signature_nonce
      # 用户在不同请求间要使用不同的随机数值，建议使用13位毫秒时间戳+4位随机数
      (Time.now.to_f.round(3) * 1000).to_i.to_s + (1000..9999).to_a.sample.to_s
    end

    def self.format_params(method = :get, params)
      {}.tap do |hash|
        params.map do |key, value|
          hash[key.to_s] = if value.is_a?(Array)
                             method == :get ? value.join("&&") : JSON.generate(value)
                           else
                             value.to_s
                           end
        end
      end
    end

    def self.escape(str)
      CGI.escape(str).gsub(/\!/, "%21")
        .gsub(/\'/, "%27")
        .gsub(/\(/, "%28")
        .gsub(/\)/, "%29")
        .gsub(/\*/, "%2A")
        .gsub(/\+/, "%20")
        .gsub(/%7E/, "~")
    end
  end
end
