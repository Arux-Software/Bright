require 'oauth'

module Bright
  module SisApi
    class InfiniteCampus < Base

      @@description = "Connects to the Infinite Campus OneRoster API for accessing student information"
      @@doc_url = "https://content.infinitecampus.com/sis/Campus.1633/documentation/oneroster-api/"
      @@api_version = "v1.1"

      attr_accessor :connection_options

      DEMOGRAPHICS_CONVERSION = {
        "americanIndianOrAlaskaNative"=>"American Indian Or Alaska Native",
        "asian"=>"Asian",
        "blackOrAfricanAmerican"=>"Black Or African American",
        "nativeHawaiianOrOtherPacificIslander"=>"Native Hawaiian Or Other Pacific Islander",
        "white"=>"White",
        "hispanicOrLatinoEthnicity"=>"Hispanic Or Latino"
      }
      def initialize(options = {})
        self.connection_options = options[:connection] || {}
        # {
        #   :client_id => "",
        #   :client_secret => "",
        #   :uri => ""
        # }
      end

      def get_student_by_api_id(api_id, params = {})
        st_hsh = self.request(:get, "users/#{api_id}", params)
        Student.new(convert_to_student_data(st_hsh["user"])) if st_hsh and st_hsh["user"]
      end

      def get_student(params = {}, options = {})
        raise NotImplementedError
      end

      def get_students(params = {}, options = {})
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

      protected

      def headers_for_auth(uri)
        site = URI.parse(self.connection_options[:uri])
        site = "#{site.scheme}://#{site.host}"
        consumer = OAuth::Consumer.new(self.connection_options[:client_id], self.connection_options[:client_secret], { :site => site, :scheme => :header })
        options = {:timestamp => Time.now.to_i, :nonce => SecureRandom.uuid}
        {"Authorization" => consumer.create_signed_request(:get, uri, nil, options)["Authorization"]}
      end

      def convert_to_student_data(student_params)
        return {} if student_params.nil?
        demographics_params = self.request(:get, "demographics/#{student_params["sourcedId"]}")["demographics"]

        student_data_hsh = {
          :api_id => student_params["sourcedId"],
          :first_name => student_params["givenName"],
          :middle_name => student_params["middleName"],
          :last_name => student_params["familyName"],
          :sis_student_id => student_params["identifier"],
          :last_modified => student_params["dateLastModified"],
          :birth_date => Date.parse(demographics_params["birthdate"]).to_s
        }
        unless demographics_params["sex"].to_s[0].nil?
          student_data_hsh[:gender] = demographics_params["sex"].to_s[0].upcase
        end
        DEMOGRAPHICS_CONVERSION.each do |demographics_key, demographics_value|
          if demographics_params[demographics_key] == "true"
            student_data_hsh[:race] ||= []
            student_data_hsh[:race] << demographics_value
          end
        end
        return student_data_hsh
      end

    end
  end
end
