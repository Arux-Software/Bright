module Bright
  module SisApi
    class Skyward < Base

      @@description = "Connects to the Skyward API for accessing student information"
      @@doc_url = "https://esdemo1.skyward.com/api/swagger/ui/index"
      @@api_version = "v1"

      attr_accessor :connection_options

      DEMOGRAPHICS_CONVERSION = {
        "I"=>"American Indian Or Alaska Native",
        "A"=>"Asian",
        "B"=>"Black Or African American",
        "P"=>"Native Hawaiian Or Other Pacific Islander",
        "W"=>"White"
      }

      def initialize(options = {})
        self.connection_options = options[:connection] || {}
        # {
        #   :client_id => "",
        #   :client_secret => "",
        #   :uri => "https://skywardinstall.com/API"
        # }
      end

      def get_student_by_api_id(api_id, params = {})
        st_hsh = self.request(:get, "v1/students/#{api_id}", params)
        Student.new(convert_to_student_data(st_hsh)) unless st_hsh.blank?
      end

      def get_school_by_api_id(api_id, params = {})
        sc_hsh = self.request(:get, "v1/schools/#{api_id}", params)
        School.new(convert_to_school_data(sc_hsh)) unless sc_hsh.blank?
      end

      def retrive_access_token
        connection = Bright::Connection.new("#{self.connection_options[:uri]}/token")
        response = connection.request(:post,
          {"grant_type" => "password",
            "username" => self.connection_options[:client_id],
            "password" => self.connection_options[:client_secret]
          },
          self.headers_for_access_token)
        if !response.error?
          response_hash = JSON.parse(response.body)
        end
        if response_hash["access_token"]
          self.connection_options[:access_token] = response_hash["access_token"]
        end
        response_hash
      end

      def request(method, path, params = {})
        uri  = "#{self.connection_options[:uri]}/#{path}"
        body = nil
        if method == :get
          query = URI.encode_www_form(params)
          uri += "?#{query}"
        else
          body = JSON.dump(params)
        end

        headers = self.headers_for_auth
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

      def convert_to_student_data(student_params)
        return {} if student_params.nil?

        student_data_hsh = {
          :api_id => student_params["NameId"],
          :first_name => student_params["FirstName"],
          :middle_name => student_params["MiddleName"],
          :last_name => student_params["LastName"],
          :sis_student_id => student_params["DisplayId"],
          :state_student_id => student_params["StateId"],
          :projected_graduation_year => student_params["GradYr"],
          :gender => student_params["Gender"],
          :hispanic_ethnicity => student_params["HispanicLatinoEthnicity"]
        }
        unless student_params["DateOfBirth"].blank?
          student_data_hsh[:birth_date] = Date.parse(student_params["DateOfBirth"]).to_s
        end

        DEMOGRAPHICS_CONVERSION.each do |demographics_key, demographics_value|
          if student_params["FederalRace"].to_s.upcase.include?(demographics_key)
            student_data_hsh[:race] ||= []
            student_data_hsh[:race] << demographics_value
          end
        end

        unless student_params["SchoolEmail"].blank?
          student_data_hsh[:email_address] = {
            :email_address => student_params["SchoolEmail"]
          }
        end

        unless student_params["DefaultSchoolId"].blank?
          student_data_hsh[:school] = self.get_school_by_api_id(student_params["DefaultSchoolId"])
        end

        return student_data_hsh
      end

      def convert_to_school_data(school_params)
        return {} if school_params.nil?

        school_data_hsh = {
          :api_id => school_params["SchoolId"],
          :name => school_params["SchoolName"],
          :low_grade => school_params["GradeLow"],
          :high_grade => school_params["GradeHigh"],
        }

        unless school_params["StreetAddress"].blank?
          school_data_hsh[:address] = {
            :street => school_params["StreetAddress"],
            :city => school_params["City"],
            :state => school_params["State"],
            :postal_code => school_params["ZipCode"]
          }
        end

        return school_data_hsh
      end

      def headers_for_access_token
        {
          "Authorization" => "Basic #{Base64.strict_encode64("#{self.connection_options[:client_id]}:#{self.connection_options[:client_secret]}")}",
          "Content-Type" => "application/x-www-form-urlencoded;charset=UTF-8"
        }
      end

      def headers_for_auth
        self.retrive_access_token if self.connection_options[:access_token].nil?
        {
          "Authorization" => "Bearer #{self.connection_options[:access_token]}",
          "Accept" => "application/json;charset=UTF-8",
          "Content-Type" =>"application/json;charset=UTF-8"
        }
      end

    end
  end
end
