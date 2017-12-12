module Bright
  module SisApi
    class InfiniteCampus < Base

      @@description = "Connects to the Infinite Campus OneRoster API for accessing student information"
      @@doc_url = "https://content.infinitecampus.com/sis/Campus.1633/documentation/oneroster-api/"
      @@api_version = "v1.1"

      attr_accessor :connection_options

      def initialize(options = {})
        self.connection_options = options[:connection] || {}
        # {
        #   :client_id => "",
        #   :client_secret => "",
        #   :uri => ""
        # }
      end

      def get_student_by_api_id(api_id, params = {})
        self.request(:get, "users/#{api_id}", params)
      end

      def get_student(params)
        raise NotImplementedError
      end

      def get_students(params)
        raise NotImplementedError
      end

      def create_student(student)
        raise NotImplementedError
      end

      def update_student(student)
        raise NotImplementedError
      end

      def get_schools(params)
        raise NotImplementedError
      end

      def request(method, path, params = {})
        uri  = "#{self.connection_options[:uri]}/#{path}"
        body = nil
        if method == :get
          query = URI.encode_www_form(params)
          uri += "?#{query}" unless query.strip == ""
        else
          body = JSON.dump(params)
        end

        headers = self.headers_for_auth(uri)

        connection = Bright::Connection.new(uri)
        response = connection.request(method, body, headers)

        if !response.error?
          response_hash = JSON.parse(response.body)
        else
          puts "#{response.inspect}"
          puts "#{response.body}"
        end
        response_hash
      end

      def headers_for_auth(uri)
        site = URI.parse(self.connection_options[:uri])
        site = "#{site.scheme}://#{site.host}"
        consumer = OAuth::Consumer.new(self.connection_options[:client_id], self.connection_options[:client_secret], { :site => site, :scheme => :header })
        options = {:timestamp => Time.now.to_i, :nonce => SecureRandom.uuid}
        {"Authorization" => consumer.create_signed_request(:get, uri, nil, options)["Authorization"]}
      end

    end
  end
end
