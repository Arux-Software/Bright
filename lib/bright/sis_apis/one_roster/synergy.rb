module Bright
  module SisApi
    class OneRoster::Synergy < OneRoster

      def api_version
        version = Gem::Version.new(connection_options.dig(:api_version) || @@api_version)
        if version == Gem::Version.new("1.1")
          raise "Synergy OneRoster requires OAuth2. Please use API Version 1.2 for the OAuth2 flow."
        end
        version
      end

      def create_student(student)
        raise NotImplementedError
      end

      def update_student(student)
        raise NotImplementedError
      end

      protected

      def retrieve_access_token
        connection = Bright::Connection.new(connection_options[:token_uri])
        response = connection.request(:post,
                                      { "grant_type" => "client_credentials" },
                                      headers_for_access_token)

        response_hash = JSON.parse(response.body) unless response.error?

        if response_hash["access_token"]
          connection_options[:access_token] = response_hash["access_token"]
          connection_options[:access_token_expires] = (Time.now - 10) + response_hash["expires_in"]
        end
        response_hash
      end
    end
  end
end
