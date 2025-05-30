require "base64"
require "json"

module Bright
  module SisApi
    class TSIS < Base
      DATE_FORMAT = "%m/%d/%Y"

      @@description = "Connects to the TIES API for accessing TIES TSIS student information"
      @@doc_url = "#unkown"

      attr_accessor :connection_options

      def initialize(options = {})
        self.connection_options = options[:connection] || {}
        # {
        #   :key => "",
        #   :secret => "",
        #   :district_id => "",
        #   :uri => ""
        # }
      end

      def get_student_by_api_id(api_id, params = {})
        get_student(params.merge({sis_student_id: api_id}))
      end

      def get_student(params = {}, options = {})
        params = apply_options(params, options.merge({per_page: 1}))

        # Students only gets you students that are enrolled in a school for a given school year.
        students_response_hash = request(:get, "Students/", map_search_params(params))
        found_student = nil
        if students_response_hash["Return"] and students_response_hash["Return"].first
          found_student = Student.new(convert_to_student_data(students_response_hash["Return"].first))
        end
        if found_student.nil?
          # Students/Family can get you students that are not enrolled in a school for a given school year.
          family_response_hash = request(:get, "Students/Family/", map_search_params(params))
          if family_response_hash["Return"] and family_response_hash["Return"].first
            found_student = Student.new(convert_to_student_data(family_response_hash["Return"].first))
          end
        end
        found_student
      end

      def get_students(params = {}, options = {})
        params = apply_options(params, options)

        response_hash = if params[:schoolyear]
          # Students only gets you students that are enrolled in a school for a given school year.
          request(:get, apply_page_to_url("Students/", options[:page]), map_search_params(params))
        else
          # Students/Family can get you students that are not enrolled in a school for a given school year.
          request(:get, apply_page_to_url("Students/Family/", options[:page]), map_search_params(params))
        end

        students = response_hash["Return"].collect { |hsh| Student.new(convert_to_student_data(hsh)) }
        total_results = response_hash["TotalCount"].to_i

        if options[:wrap_in_collection] != false
          api = self
          load_more_call = proc { |page|
            # pages start at one, so add a page here
            api.get_students(params, {wrap_in_collection: false, page: (page + 1)})
          }

          ResponseCollection.new({
            seed_page: students,
            total: total_results,
            per_page: options[:per_page],
            load_more_call: load_more_call
          })
        else
          students
        end
      end

      def create_student(student)
        raise NotImplementedError, "TSIS does not support creating students"
      end

      def update_student(student)
        raise NotImplementedError, "TSIS does not support updating students"
      end

      def get_schools(params = {}, options = {})
        params = apply_options(params, options)

        # schools api end point takes page # in the url itself for some reason
        schools_response_hash = request(:get, apply_page_to_url("Schools/", options[:page]), params)

        schools = schools_response_hash["Return"].collect { |hsh| School.new(convert_to_school_data(hsh)) }
        total_results = schools_response_hash["TotalCount"].to_i

        if options[:wrap_in_collection] != false
          api = self
          load_more_call = proc { |page|
            # pages start at one, so add a page here
            api.get_schools(params, {wrap_in_collection: false, page: (page + 1)})
          }

          ResponseCollection.new({
            seed_page: schools,
            total: total_results,
            per_page: options[:per_page],
            load_more_call: load_more_call
          })
        else
          schools
        end
      end

      def request(method, path, params = {})
        uri = "#{connection_options[:uri]}/#{path}"
        body = nil
        query = URI.encode(params.map { |k, v| "#{k}=#{v}" }.join("&"))
        if method == :get
          uri += "?#{query}"
        else
          body = query
        end

        response = connection_retry_wrapper {
          connection = Bright::Connection.new(uri)
          headers = headers_for_auth
          connection.request(method, body, headers)
        }

        if !response.error?
          response_hash = JSON.parse(response.body)
        end
        response_hash
      end

      protected

      def map_search_params(params)
        params = params.dup

        params["studentname"] = params.delete(:name)
        params["studentname"] ||= "#{params.delete(:last_name)}, #{params.delete(:first_name)} #{params.delete(:middle_name)}".strip
        params["studentids"] = params.delete(:sis_student_id)

        params = params.collect do |k, v|
          if v.is_a?(Array)
            v = v.join(",")
          end
          k = k.to_s.gsub(/[^A-Za-z]/, "").downcase
          [k, v]
        end.to_h

        params.reject { |k, v| v.respond_to?(:empty?) ? v.empty? : v.nil? }
      end

      def convert_to_student_data(attrs)
        catt = {}
        if attrs["StudentName"]
          split_name = attrs["StudentName"].strip.split(",")
          if split_name[1]
            split_first_name = split_name[1].to_s.strip.split(" ")
            if split_first_name.size > 1
              catt[:first_name] = split_first_name[0...-1].join(" ").strip
              catt[:middle_name] = split_first_name[-1].strip
            else
              catt[:first_name] = split_first_name.first.strip
            end
          end
          catt[:last_name] = split_name[0].to_s.strip
        else
          catt[:first_name] = attrs["FirstName"].strip
          catt[:middle_name] = attrs["MiddleName"].strip
          catt[:last_name] = (attrs["LastName"] || attrs["SurName"]).strip
        end

        catt[:state_student_id] = (attrs["StateId"] || attrs["StudentStateId"]).to_s
        catt[:sis_student_id] = attrs["StudentId"].to_s
        catt[:api_id] = attrs["StudentId"].to_s
        catt[:homeless_code] = attrs["HomelessCode"]

        # "Economic\":{\"Description\":\"\",\"EconomicIndicatorId\":\"0\"}

        bd = attrs["BirthDate"] || attrs["StudentBirthDate"]
        if !(bd.nil? or bd.empty?)
          begin
            catt[:birth_date] = Date.strptime(bd, DATE_FORMAT)
          rescue => e
            puts "#{e.inspect} #{bd}"
          end
        end

        catt[:addresses] = [convert_to_address_data(attrs["Address"])] if attrs["Address"]

        catt.reject { |k, v| v.respond_to?(:empty?) ? v.empty? : v.nil? }
      end

      def convert_to_address_data(attrs)
        cattrs = {}

        if attrs["Line1"]
          cattrs[:street] = "#{attrs["Line1"]}\n#{attrs["Line2"]}\n#{attrs["Line3"]}".strip
        elsif attrs["Address1"]
          cattrs[:street] = "#{attrs["Address1"]}\n#{attrs["Address2"]}".strip
        end
        cattrs[:city] = attrs["City"]
        cattrs[:state] = attrs["State"]
        cattrs[:postal_code] = attrs["Zip"]
        cattrs[:type] = attrs["Type"].to_s.downcase

        cattrs.reject { |k, v| v.respond_to?(:empty?) ? v.empty? : v.nil? }
      end

      def convert_to_school_data(attrs)
        cattrs = {}

        cattrs[:name] = attrs["Name"]
        cattrs[:api_id] = cattrs[:number] = attrs["SchoolId"]
        cattrs[:address] = convert_to_address_data(attrs)

        cattrs.reject { |k, v| v.respond_to?(:empty?) ? v.empty? : v.nil? }
      end

      def apply_options(params, options)
        options[:per_page] = params[:rpp] ||= params.delete(:per_page) || options[:per_page] || 100
        options[:page] = params.delete(:page) || options[:page]
        params[:schoolyear] ||= params.delete(:school_year) || options[:school_year]
        params
      end

      def apply_page_to_url(url, page)
        "#{url}#{(url[-1] == "/") ? "" : "/"}#{page}"
      end

      def headers_for_auth(uri)
        t = Time.now.utc.httpdate
        string_to_sign = "GET\n#{t}\n#{uri}"

        signature = Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new("sha1"), connection_options[:secret], string_to_sign)).strip
        authorization = "TIES" + " " + connection_options[:key] + ":" + signature

        {
          "Authorization" => authorization,
          "DistrictNumber" => connection_options[:district_id],
          "ties-date" => t,
          "Content-Type" => "application/json"
        }
      end
    end
  end
end
