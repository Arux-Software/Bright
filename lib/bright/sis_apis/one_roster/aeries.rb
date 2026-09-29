module Bright
  module SisApi
    class OneRoster::Aeries < OneRoster
      def initialize(options = {})
        self.connection_options = options[:connection] || {}
        # https://support.aeries.com/support/solutions/articles/14000065677-oneroster-api-authentication-process
        # ALL of the below are required
        # {
        #   :client_id => "",
        #   :client_secret => "",
        #   :uri => "",
        #   :token_uri => "",
        #   :scope => ""
        # }
      end

      def retrieve_access_token
        connection = Bright::Connection.new(connection_options[:token_uri])
        response = connection.request(:post,
          {
            "grant_type" => "client_credentials",
            "username" => connection_options[:client_id],
            "password" => connection_options[:client_secret],
            "scope" => connection_options[:scope]
          },
          headers_for_access_token)
        if !response.error?
          response_hash = JSON.parse(response.body)
        end
        if response_hash["access_token"]
          connection_options[:access_token] = response_hash["access_token"]
          connection_options[:access_token_expires] = (Time.now - 10) + response_hash["expires_in"]
        end
        response_hash
      end
    end
  end
end
