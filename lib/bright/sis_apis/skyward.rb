module Bright
  module SisApi
    class Skyward < Base

      @@description = "Connects to the Skyward API for accessing student information"
      @@doc_url = "https://esdemo1.skyward.com/api/swagger/ui/index"
      @@api_version = "v1"

      attr_accessor :connection_options, :schools_cache

      DEMOGRAPHICS_CONVERSION = {
        "I"=>"American Indian Or Alaska Native",
        "A"=>"Asian",
        "B"=>"Black Or African American",
        "P"=>"Native Hawaiian Or Other Pacific Islander",
        "W"=>"White"
      }

      PHONE_TYPE_CONVERSION = {
        "Cellular" => "Cell",
        "Work" => "Work",
        "Home" => "Home",
        "Other" => "Other"
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
        st_hsh = self.request(:get, "v1/students/#{api_id}", params)[:parsed_body]
        Student.new(convert_to_user_data(st_hsh, {:type => "Student"})) unless st_hsh.blank?
      end

      def get_students(params = {}, options = {})
        params["paging.limit"] = params[:limit] || options[:limit] || 1000
        students_response = self.request(:get, 'v1/students', params)
        if !students_response[:parsed_body].blank?
          students = students_response[:parsed_body].compact.collect {|st_hsh|
            Student.new(convert_to_user_data(st_hsh, {:type => "Student"}))
          }
        end

        next_cursor = nil
        if students_response[:headers]["Link"]
          students_response[:headers]["Link"].split(",").each do |part, index|
            section = part.split(';')
            url = section[0][/<(.*)>/,1]
            name = section[1][/rel="(.*)"/,1].to_s
            if name == "next"
              next_cursor = CGI.parse(URI.parse(url).query)["cursor"].first
            end
          end
        end
        if options[:wrap_in_collection] != false
          api = self
          load_more_call = proc {|cursor|
            params["paging.cursor"] = cursor
            options = {:wrap_in_collection => false, :include_cursor => true}
            api.get_students(params, options)
          }
          CursorResponseCollection.new({
            :seed_page => students,
            :load_more_call => load_more_call,
            :next_cursor => next_cursor
          })
        elsif options[:include_cursor] == true
          return {:objects => students, :next_cursor => next_cursor}
        else
          return students
        end
      end

      def get_school_by_api_id(api_id, params = {})
        sc_hsh = self.request(:get, "v1/schools/#{api_id}", params)[:parsed_body]
        School.new(convert_to_school_data(sc_hsh)) unless sc_hsh.blank?
      end

      def get_schools(params = {}, options = {})
        params["paging.limit"] = params[:limit] || options[:limit] || 10000
        schools_hshs = self.request(:get, "v1/schools", params)[:parsed_body]
        if !schools_hshs.blank?
          schools = schools_hshs.compact.collect {|sc_hsh|
            School.new(convert_to_school_data(sc_hsh))
          }
        end
        return schools
      end

      def get_contact_by_api_id(api_id, params = {})
        contact_hsh = self.request(:get, "v1/names/#{api_id}", params)[:parsed_body]
        Contact.new(convert_to_user_data(contact_hsh, {:type => "Contact"})) unless contact_hsh.blank?
      end

      def get_guardians_by_api_id(api_id, params = {})
        guardians = []
        guardians_array = self.request(:get, "v1/guardians", params.merge({"studentNameId" => api_id}))[:parsed_body]
        if !guardians_array.blank?
          guardians_array.each do |guardian_hsh|
            relationship_type = guardian_hsh.delete("Students").detect{|s_hsh| s_hsh["StudentNameId"].to_s == api_id.to_s}["RelationshipDesc"]
            guardian_hsh["RelationshipType"] = relationship_type
            guardian_hsh["NameId"] = guardian_hsh.delete("GuardianNameId")
            guardians << Contact.new(convert_to_user_data(guardian_hsh, {:type => "Contact"}))
          end
        end
        return guardians
      end

      def retrieve_access_token
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
          self.connection_options[:access_token_expires] = (Time.now - 10) + response_hash["expires_in"]
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

        response = connection_retry_wrapper {
          connection = Bright::Connection.new(uri)
          headers = self.headers_for_auth
          connection.request(method, body, headers)
        }

        if !response.error?
          response_hash = JSON.parse(response.body)
        else
          puts "#{response.inspect}"
          puts "#{response.body}"
        end
        return {:parsed_body => response_hash, :headers => response.headers}
      end

      protected

      def convert_to_user_data(user_params, options = {})
        # :type => "Contact" || "Student"
        return {} if user_params.blank?

        user_data_hsh = {
          :api_id => user_params["NameId"],
          :first_name => user_params["FirstName"],
          :middle_name => user_params["MiddleName"],
          :last_name => user_params["LastName"],
          :sis_student_id => user_params["DisplayId"],
          :state_student_id => user_params["StateId"],
          :projected_graduation_year => user_params["GradYr"],
          # To avoid a mismatch of attributes, we'll ignore for now
          # :gender => user_params["Gender"],
          :hispanic_ethnicity => user_params["HispanicLatinoEthnicity"],
          :relationship_type => user_params["RelationshipType"]
        }.reject{|k,v| v.blank?}
        unless user_params["DateOfBirth"].blank?
          user_data_hsh[:birth_date] = Date.parse(user_params["DateOfBirth"]).to_s
        end

        DEMOGRAPHICS_CONVERSION.each do |demographics_key, demographics_value|
          if user_params["FederalRace"].to_s.upcase.include?(demographics_key)
            user_data_hsh[:race] ||= []
            user_data_hsh[:race] << demographics_value
          end
        end

        unless user_params["SchoolEmail"].blank?
          user_data_hsh[:email_address] = {
            :email_address => user_params["SchoolEmail"]
          }
        end

        unless user_params["Email"].blank?
          user_data_hsh[:email_address] = {
            :email_address => user_params["Email"]
          }
        end

        unless user_params["DefaultSchoolId"].blank?
          self.schools_cache ||= {}
          if (attending_school = self.schools_cache[user_params["DefaultSchoolId"]]).nil?
            attending_school = self.get_school_by_api_id(user_params["DefaultSchoolId"])
            self.schools_cache[attending_school.api_id] = attending_school
          end
          user_data_hsh[:school] = attending_school
        end

        unless user_params["StreetAddress"].blank?
          user_data_hsh[:addresses] = [{
            :street => user_params["StreetAddress"],
            :city => user_params["City"],
            :state => user_params["State"],
            :postal_code => user_params["ZipCode"]
          }]
        end

        ["PhoneNumber", "PhoneNumber2", "PhoneNumber3"].each do |phone_param|
          if user_params[phone_param].present? && user_params["#{phone_param}Type"].present?
            user_data_hsh[:phone_numbers] ||= []
            user_data_hsh[:phone_numbers] << {
              :phone_number => user_params[phone_param],
              :type => PHONE_TYPE_CONVERSION[user_params["#{phone_param}Type"]]
            }
          end
        end

        if options[:type] == "Student"
          #generate the contacts for a student
          user_data_hsh[:contacts] = self.get_guardians_by_api_id(user_data_hsh[:api_id])
        end

        return user_data_hsh
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
        if self.connection_options[:access_token].nil? or self.connection_options[:access_token_expires] < Time.now
          self.retrieve_access_token
        end
        {
          "Authorization" => "Bearer #{self.connection_options[:access_token]}",
          "Accept" => "application/json;charset=UTF-8",
          "Content-Type" =>"application/json;charset=UTF-8"
        }
      end

    end
  end
end
