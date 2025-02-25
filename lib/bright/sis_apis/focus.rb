require "oauth"

module Bright
  module SisApi
    class Focus < Base
      @@description = "Connects to the Focus OneRoster API for accessing student information"
      @@doc_url = ""
      @@api_version = "1.1"

      attr_accessor :connection_options, :schools_cache, :school_years_cache

      DEFAULT_NO_THREADS = 2

      DEMOGRAPHICS_CONVERSION = {
        "americanIndianOrAlaskaNative" => "American Indian Or Alaska Native",
        "asian" => "Asian",
        "blackOrAfricanAmerican" => "Black Or African American",
        "nativeHawaiianOrOtherPacificIslander" => "Native Hawaiian Or Other Pacific Islander",
        "white" => "White",
        "hispanicOrLatinoEthnicity" => "Hispanic Or Latino"
      }

      def initialize(options = {})
        self.connection_options = options[:connection] || {}
        # {
        #   :client_id => "",
        #   :client_secret => "",
        #   :api_version => "", (defaults to @@api_version)
        #   :uri => "",
        #   :token_uri => ""  (api_version 1.2 required)
        # }
      end

      def api_version
        Gem::Version.new(connection_options.dig(:api_version) || @@api_version)
      end

      def get_student_by_api_id(api_id, params = {})
        st_hsh = request(:get, "students/#{api_id}", params)
        Student.new(convert_to_user_data(st_hsh["user"])) if st_hsh and st_hsh["user"]
      end

      def get_student(params = {}, options = {})
        get_students(params, options.merge(limit: 1, wrap_in_collection: false)).first
      end

      def get_students(params = {}, options = {})
        params[:limit] = params[:limit] || options[:limit] || 100
        students_response_hash = request(:get, "students", map_search_params(params))
        total_results = students_response_hash[:response_headers]["x-total-count"].to_i
        if students_response_hash and students_response_hash["users"]
          students_hash = [students_response_hash["users"]].flatten

          students = students_hash.compact.collect { |st_hsh|
            Student.new(convert_to_user_data(st_hsh))
          }
        end
        if options[:wrap_in_collection] != false
          api = self
          load_more_call = proc { |page|
            # pages start at one, so add a page here
            params[:offset] = (params[:limit].to_i * page)
            api.get_students(params, {wrap_in_collection: false})
          }
          ResponseCollection.new({
            seed_page: students,
            total: total_results,
            per_page: params[:limit],
            load_more_call: load_more_call,
            no_threads: options[:no_threads] || DEFAULT_NO_THREADS
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

      def get_school_by_api_id(api_id, params = {})
        sc_hsh = request(:get, "schools/#{api_id}", params)
        School.new(convert_to_school_data(sc_hsh["org"])) if sc_hsh and sc_hsh["org"]
      end

      def get_school(params = {}, options = {})
        get_schools(params, options.merge(limit: 1, wrap_in_collection: false)).first
      end

      def get_schools(params = {}, options = {})
        params[:limit] = params[:limit] || options[:limit] || 100
        schools_response_hash = request(:get, "schools", map_school_search_params(params))
        total_results = schools_response_hash[:response_headers]["x-total-count"].to_i
        if schools_response_hash and schools_response_hash["orgs"]
          schools_hash = [schools_response_hash["orgs"]].flatten

          schools = schools_hash.compact.collect { |sc_hsh|
            School.new(convert_to_school_data(sc_hsh))
          }
        end
        if options[:wrap_in_collection] != false
          api = self
          load_more_call = proc { |page|
            # pages start at one, so add a page here
            params[:offset] = (params[:limit].to_i * page)
            api.get_schools(params, {wrap_in_collection: false})
          }
          ResponseCollection.new({
            seed_page: schools,
            total: total_results,
            per_page: params[:limit],
            load_more_call: load_more_call,
            no_threads: options[:no_threads]
          })
        else
          schools
        end
      end

      def get_contact_by_api_id(api_id, params = {})
        contact_hsh = request(:get, "users/#{api_id}", params)
        Contact.new(convert_to_user_data(contact_hsh["user"], bright_type: "Contact")) if contact_hsh and contact_hsh["user"]
      end

      def request(method, path, params = {})
        uri = "#{connection_options[:uri]}/#{path}"
        body = nil
        if method == :get
          query = URI.encode_www_form(params)
          uri += "?#{query}" unless query.strip == ""
        else
          body = JSON.dump(params)
        end

        response = connection_retry_wrapper {
          connection = Bright::Connection.new(uri)
          headers = headers_for_auth(uri)
          connection.request(method, body, headers)
        }

        if !response.error?
          response_hash = JSON.parse(response.body)
          response_hash[:response_headers] = response.headers
        else
          puts "#{response.inspect}"
          puts "#{response.body}"
        end
        response_hash
      end

      protected

      def headers_for_auth(uri)
        case api_version
        when Gem::Version.new("1.1")
          site = URI.parse(connection_options[:uri])
          site = "#{site.scheme}://#{site.host}"
          consumer = OAuth::Consumer.new(connection_options[:client_id], connection_options[:client_secret], {site: site, scheme: :header})
          options = {timestamp: Time.now.to_i, nonce: SecureRandom.uuid}
          {"Authorization" => consumer.create_signed_request(:get, uri, nil, options)["Authorization"]}
        when Gem::Version.new("1.2")
          if connection_options[:access_token].nil? or connection_options[:access_token_expires] < Time.now
            retrieve_access_token
          end
          {
            "Authorization" => "Bearer #{connection_options[:access_token]}",
            "Accept" => "application/json;charset=UTF-8",
            "Content-Type" => "application/json;charset=UTF-8"
          }
        end
      end

      def retrieve_access_token
        connection = Bright::Connection.new(connection_options[:token_uri])
        response = connection.request(:post,
          {
            "grant_type" => "client_credentials",
            "username" => connection_options[:client_id],
            "password" => connection_options[:client_secret]
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

      def headers_for_access_token
        {
          "Authorization" => "Basic #{Base64.strict_encode64("#{connection_options[:client_id]}:#{connection_options[:client_secret]}")}",
          "Content-Type" => "application/x-www-form-urlencoded;charset=UTF-8"
        }
      end

      def map_search_params(params)
        params = params.dup
        default_params = {}

        filter = []
        params.each do |k, v|
          case k.to_s
          when "first_name"
            filter << "givenName='#{v}'"
          when "last_name"
            filter << "familyName='#{v}'"
          when "email"
            filter << "email='#{v}'"
          when "student_id"
            filter << "identifier='#{v}'"
          when "last_modified"
            filter << "dateLastModified>='#{v.to_time.utc.xmlschema}'"
          when "role"
            filter << "role='#{v}'"
          else
            default_params[k] = v
          end
        end
        unless filter.empty?
          params = {"filter" => filter.join(" AND ")}
        end
        default_params.merge(params).reject { |k, v| v.respond_to?(:empty?) ? v.empty? : v.nil? }
      end

      def map_school_search_params(params)
        params = params.dup
        default_params = {}
        filter = []
        params.each do |k, v|
          case k.to_s
          when "number"
            filter << "identifier='#{v}'"
          when "last_modified"
            filter << "dateLastModified>='#{v.to_time.utc.xmlschema}'"
          else
            default_params[k] = v
          end
        end
        unless filter.empty?
          params = {"filter" => filter.join(" AND ")}
        end
        default_params.merge(params).reject { |k, v| v.respond_to?(:empty?) ? v.empty? : v.nil? }
      end

      def convert_to_school_data(school_params)
        return {} if school_params.blank?
        {
          api_id: school_params["sourcedId"],
          name: school_params["name"],
          number: school_params["identifier"],
          last_modified: school_params["dateLastModified"]
        }
      end

      def convert_to_user_data(user_params, bright_type: "Student")
        return {} if user_params.blank?
        user_data_hsh = {
          api_id: user_params["sourcedId"],
          first_name: user_params["givenName"],
          middle_name: user_params["middleName"],
          last_name: user_params["familyName"],
          last_modified: user_params["dateLastModified"]
        }.reject { |k, v| v.blank? }
        unless user_params["identifier"].blank?
          user_data_hsh[:sis_student_id] = user_params["identifier"]
        end
        unless user_params["userMasterIdentifier"].blank?
          user_data_hsh[:state_student_id] = user_params["userMasterIdentifier"]
        end
        unless user_params.dig("metadata", "stateId").blank?
          user_data_hsh[:state_student_id] = user_params.dig("metadata", "stateId")
        end
        unless user_params["email"].blank?
          user_data_hsh[:email_address] = {
            email_address: user_params["email"]
          }
        end
        unless user_params["orgs"].blank?
          if (s = user_params["orgs"].detect { |org| org["href"] =~ /\/schools\// })
            self.schools_cache ||= {}
            if (attending_school = self.schools_cache[s["sourcedId"]]).nil?
              attending_school = get_school_by_api_id(s["sourcedId"])
              self.schools_cache[attending_school.api_id] = attending_school
            end
          end
          if attending_school
            user_data_hsh[:school] = attending_school
          end
        end
        unless user_params["phone"].blank?
          user_data_hsh[:phone_numbers] = [{phone_number: user_params["phone"]}]
        end
        unless user_params["sms"].blank?
          user_data_hsh[:phone_numbers] ||= []
          user_data_hsh[:phone_numbers] << {phone_number: user_params["sms"]}
        end

        # add the demographic information
        demographics_hash = get_demographic_information(user_data_hsh[:api_id])
        user_data_hsh.merge!(demographics_hash) unless demographics_hash.blank?

        # if you're a student, build the contacts too
        if bright_type == "Student" and !user_params["agents"].blank?
          user_data_hsh[:contacts] = user_params["agents"].collect do |agent_hsh|
            get_contact_by_api_id(agent_hsh["sourcedId"])
          rescue Bright::ResponseError => e
            if !e.message.to_s.include?("404")
              raise e
            end
          end.compact
          user_data_hsh[:grade] = (user_params["grades"] || []).first
          if !user_data_hsh[:grade].blank?
            user_data_hsh[:grade_school_year] = get_grade_school_year
          end
        end

        user_data_hsh
      end

      def get_demographic_information(api_id)
        demographic_hsh = {}

        begin
          demographics_params = request(:get, "demographics/#{api_id}")["demographics"]
        rescue Bright::ResponseError => e
          if e.message.to_s.include?("404")
            return demographic_hsh
          else
            raise e
          end
        end

        unless (bday = demographics_params["birthdate"] || demographics_params["birthDate"]).blank?
          demographic_hsh[:birth_date] = Date.parse(bday).to_s
        end
        unless demographics_params["sex"].to_s[0].blank?
          demographic_hsh[:sex] = demographics_params["sex"].to_s[0].upcase
        end
        DEMOGRAPHICS_CONVERSION.each do |demographics_key, demographics_value|
          if demographics_params[demographics_key].to_bool
            if demographics_value == "Hispanic Or Latino"
              demographic_hsh[:hispanic_ethnicity] = true
            else
              demographic_hsh[:race] ||= []
              demographic_hsh[:race] << demographics_value
            end
          end
        end
        demographic_hsh
      end

      def get_grade_school_year(date = Date.today)
        # return the school year of a specific date
        self.school_years_cache ||= {}
        if self.school_years_cache[date].nil?
          academic_periods_params = request(:get, "academicSessions", {"filter" => "startDate<='#{date}' AND endDate>='#{date}' AND status='active'"})["academicSessions"]
          school_years = academic_periods_params.map { |ap| ap["schoolYear"] }.uniq
          if school_years.size == 1
            self.school_years_cache[date] = school_years.first
          end
        end
        self.school_years_cache[date]
      end
    end
  end
end
