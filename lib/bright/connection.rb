require 'uri'
require 'httpi'
require 'benchmark'
require 'securerandom'

module Bright
  class Connection
    OPEN_TIMEOUT = 60
    READ_TIMEOUT = 60
    VERIFY_PEER = true

    attr_accessor :endpoint
    attr_accessor :open_timeout
    attr_accessor :read_timeout
    attr_accessor :verify_peer
    attr_accessor :ssl_version
    attr_accessor :pem
    attr_accessor :pem_password
    attr_accessor :logger
    attr_accessor :tag
    attr_accessor :ignore_http_status
    attr_accessor :proxy_address
    attr_accessor :proxy_port

    def initialize(endpoint)
      @endpoint     = endpoint.is_a?(URI) ? endpoint : URI.parse(endpoint)
      @open_timeout = OPEN_TIMEOUT
      @read_timeout = READ_TIMEOUT
      @verify_peer  = VERIFY_PEER
      @ignore_http_status = false
      @ssl_version = nil
      @proxy_address = nil
      @proxy_port = nil
    end

    def request(method, body, headers = {})
      request_start = Time.now.to_f

      begin
        info "connection_http_method=#{method.to_s.upcase} connection_uri=#{endpoint}", tag

        result = nil

        if !Bright.devmode
          HTTPI.log = false
        end

        realtime = Benchmark.realtime do
          request = HTTPI::Request.new(endpoint.to_s)
          request.headers = headers
          request.body = body if body
          request.auth.ssl.verify_mode = :none if !@verify_peer
          configure_proxy(request)
          configure_timeouts(request)

          result = case method
          when :get
            raise ArgumentError, "GET requests do not support a request body" if body
            HTTPI.get(request)
          when :post
            debug(body) if Bright.devmode
            HTTPI.post(request)
          when :put
            debug(body) if Bright.devmode
            HTTPI.put(request)
          when :patch
            debug(body) if Bright.devmode
            HTTPI.patch(request)
          when :delete
            HTTPI.delete(request)
          else
            raise ArgumentError, "Unsupported request method #{method.to_s.upcase}"
          end
        end

        if Bright.devmode
          info("--> %d (%d %.4fs)" % [result.code, result.body ? result.body.length : 0, realtime], tag)
          debug(result.body)
        end
        handle_response(result)
      end
    ensure
      info "connection_request_total_time=%.4fs" % [Time.now.to_f - request_start], tag
    end

    private
    def configure_proxy(http)
      http.proxy = "#{proxy_address}:#{proxy_port}" if proxy_address
    end

    def configure_timeouts(http)
      http.open_timeout = open_timeout
      http.read_timeout = read_timeout
    end

    def handle_response(response)
      if @ignore_http_status or !response.error?
        return response
      else
        raise ResponseError.new(response)
      end
    end

    def debug(message, tag = nil)
      log(:debug, message, tag)
    end

    def info(message, tag = nil)
      log(:info, message, tag)
    end

    def error(message, tag = nil)
      log(:error, message, tag)
    end

    def log(level, message, tag)
      message = "[#{tag}] #{message}" if tag
      logger.send(level, message) if logger
    end
  end
end
