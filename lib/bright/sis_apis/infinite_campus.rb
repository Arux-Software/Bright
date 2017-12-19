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
        self.get_students(params, options.merge(:limit => 1, :wrap_in_collection => false)).first
      end

      def get_students(params = {}, options = {})
        params[:limit] = params[:limit] || options[:limit] || 100
        total_results = 500
        students_response_hash = self.request(:get, 'users', self.map_student_search_params(params))
        if students_response_hash and students_response_hash["users"]
          students_hash = [students_response_hash["users"]].flatten

          students = students_hash.compact.collect {|st_hsh|
            Student.new(convert_to_student_data(st_hsh))
          }
        end
        if options[:wrap_in_collection] != false
          api = self
          load_more_call = proc { |page|
            # pages start at one, so add a page here
            params[:offset] = (params[:limit].to_i * page)
            api.get_students(params, {:wrap_in_collection => false})
          }
          ResponseCollection.new({
            :seed_page => students,
            :total => total_results,
            :per_page => params[:limit],
            :load_more_call => load_more_call
          })
        else
          students
        end
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
        puts uri.inspect
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

      def map_student_search_params(params)
        params = params.dup
        default_params = {}

        filter = []
        params.each do |k,v|
          case k.to_s
          when "first_name"
            filter << "givenName='#{v}'"
          when "last_name"
            filter << "familyName='#{v}'"
          when "email"
            filter << "email='#{v}'"
          when "student_id"
            filter << "identifier='#{v}'"
          else
            default_params[k] = v
          end
        end
        unless filter.empty?
          params = {"filter" => filter.join(" AND ")}
        end
        default_params.merge(params).reject{|k,v| v.respond_to?(:empty?) ? v.empty? : v.nil?}
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
          :last_modified => student_params["dateLastModified"]
        }
        unless demographics_params["birthdate"].nil?
          student_data_hsh[:birth_date] = Date.parse(demographics_params["birthdate"]).to_s
        end
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
