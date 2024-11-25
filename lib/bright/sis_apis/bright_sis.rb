module Bright
  module SisApi
    class BrightSis < Base
      @@description = "Connects to the Bright SIS Data Store"
      @@doc_url = ""
      @@api_version = "v1"

      attr_accessor :connection_options

      DEMOGRAPHICS_CONVERSION = {
        "I" => "American Indian Or Alaska Native",
        "A" => "Asian",
        "B" => "Black Or African American",
        "P" => "Native Hawaiian Or Other Pacific Islander",
        "W" => "White",
        "M" => "Other"
      }

      def initialize(options = {})
        self.connection_options = options[:connection] || {}
        # {
        #   :access_token => ""
        #   :uri => ""
        # }
      end

      def get_student_by_api_id(api_id, options = {})
        get_students({"uuid" => api_id}, options.merge(limit: 1, wrap_in_collection: false)).first
      end

      def get_student(params = {}, options = {})
        get_students(params, options.merge(limit: 1, wrap_in_collection: false)).first
      end

      def get_students(params = {}, options = {})
        params[:limit] = params[:limit] || options[:limit] || 100
        students_response_hash = request(:get, "students", map_student_search_params(params))
        total_results = students_response_hash[:response_headers]["total"].to_i
        if students_response_hash and students_response_hash["students"]
          students_hash = [students_response_hash["students"]].flatten

          students = students_hash.compact.collect { |st_hsh|
            Student.new(convert_to_student_data(st_hsh))
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
            no_threads: options[:no_threads]
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

      def get_schools(params = {}, options = {})
        params[:limit] = params[:limit] || options[:limit] || 100
        schools_response_hash = request(:get, "schools", map_school_search_params(params))
        total_results = schools_response_hash[:response_headers]["total"].to_i
        if schools_response_hash and schools_response_hash["schools"]
          schools_hash = [schools_response_hash["schools"]].flatten

          schools = schools_hash.compact.collect { |st_hsh|
            School.new(convert_to_school_data(st_hsh))
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
          headers = headers_for_auth
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
        {"Authorization" => "Token token=#{connection_options[:access_token]}"}
      end

      def map_student_search_params(attrs)
        filter_params = {}
        attrs.each do |k, v|
          case k.to_s
          when "api_id"
            filter_params["uuid"] = v
          when "sis_student_id"
            filter_params["student_number"] = v
          when "state_student_id"
            filter_params["state_id"] = v
          else
            filter_params[k] = v
          end
        end
        filter_params
      end

      def convert_to_student_data(student_params)
        return {} if student_params.nil?
        student_data_hsh = {
          api_id: student_params["uuid"],
          first_name: student_params["first_name"],
          middle_name: student_params["middle_name"],
          last_name: student_params["last_name"],
          sis_student_id: student_params["student_number"],
          state_student_id: student_params["state_id"],
          grade: student_params["grade"],
          grade_school_year: student_params["grade_school_year"],
          projected_graduation_year: student_params["graduation_year"],
          sex: student_params["sex"],
          frl_status: student_params["frl_status"],
          image: student_params["picture"],
          hispanic_ethnicity: student_params["hispanic_latino"],
          last_modified: student_params["updated_at"]
        }.reject { |k, v| v.blank? }
        unless student_params["birthdate"].blank?
          student_data_hsh[:birth_date] = Date.parse(student_params["birthdate"]).to_s
        end

        DEMOGRAPHICS_CONVERSION.each do |demographics_key, demographics_value|
          if student_params["race"].to_s.upcase.include?(demographics_key)
            student_data_hsh[:race] ||= []
            student_data_hsh[:race] << demographics_value
          end
        end

        unless student_params["addresses"].blank?
          student_data_hsh[:addresses] = student_params["addresses"].collect do |address_params|
            convert_to_address_data(address_params)
          end
        end

        unless student_params["phone_numbers"].blank?
          student_data_hsh[:phone_numbers] = student_params["phone_numbers"].collect do |phone_params|
            convert_to_phone_number_data(phone_params)
          end
        end

        unless student_params["email_addresses"].blank?
          student_data_hsh[:email_address] = {
            email_address: student_params["email_addresses"].first["email_address"]
          }
        end

        unless student_params["school"].blank?
          student_data_hsh[:school] = convert_to_school_data(student_params["school"])
        end

        unless student_params["contacts"].blank?
          student_data_hsh[:contacts] = student_params["contacts"].collect do |contact_params|
            contact_data_hsh = {
              api_id: contact_params["uuid"],
              first_name: contact_params["first_name"],
              middle_name: contact_params["middle_name"],
              last_name: contact_params["last_name"],
              relationship_type: contact_params["relationship"],
              sis_student_id: contact_params["sis_id"],
              last_modified: contact_params["updated_at"]
            }
            unless contact_params["addresses"].blank?
              contact_data_hsh[:addresses] = contact_params["addresses"].collect do |address_params|
                convert_to_address_data(address_params)
              end
            end
            unless contact_params["phone_numbers"].blank?
              contact_data_hsh[:phone_numbers] = contact_params["phone_numbers"].collect do |phone_params|
                convert_to_phone_number_data(phone_params)
              end
            end
            unless contact_params["email_addresses"].blank?
              contact_data_hsh[:email_address] = {
                email_address: contact_params["email_addresses"].first["email_address"]
              }
            end
            contact_data_hsh.reject { |k, v| v.blank? }
          end
        end

        student_data_hsh
      end

      def map_school_search_params(attrs)
        filter_params = {}
        attrs.each do |k, v|
          case k.to_s
          when "api_id"
            filter_params["id"] = v
          else
            filter_params[k] = v
          end
        end
        filter_params
      end

      def convert_to_phone_number_data(phone_number_params)
        return {} if phone_number_params.nil?
        {
          phone_number: phone_number_params["phone_number"],
          type: phone_number_params["phone_type"]
        }.reject { |k, v| v.blank? }
      end

      def convert_to_address_data(address_params)
        return {} if address_params.nil?
        {
          street: address_params["street"],
          apt: address_params["street_line_2"],
          city: address_params["city"],
          state: address_params["state"],
          postal_code: address_params["zip"],
          lattitude: address_params["latitude"],
          longitude: address_params["longitude"],
          type: address_params["address_type"]
        }.reject { |k, v| v.blank? }
      end

      def convert_to_school_data(school_params)
        return {} if school_params.nil?

        school_data_hsh = {
          api_id: school_params["id"],
          name: school_params["name"],
          number: school_params["number"],
          state_id: school_params["state_id"],
          low_grade: school_params["low_grade"],
          high_grade: school_params["high_grade"],
          last_modified: school_params["updated_at"]
        }

        unless school_params["school_address"].blank?
          school_data_hsh[:address] = {
            street: school_params["school_address"],
            city: school_params["school_city"],
            state: school_params["school_state"],
            postal_code: school_params["school_zip"]
          }
        end

        unless school_params["school_phone"].blank?
          school_data_hsh[:phone_number] = {
            phone_number: school_params["school_phone"]
          }
        end

        school_data_hsh
      end
    end
  end
end
