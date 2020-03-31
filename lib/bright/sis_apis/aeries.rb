module Bright
  module SisApi
    class Aeries < Base
      DATE_FORMAT = '%Y-%m-%dT%H:%M:%S'

      @@description = "Connects to the Aeries API for accessing student information"
      @@doc_url = "http://www.aeries.com/downloads/docs.1234/TechnicalSpecs/Aeries_API_Documentation.pdf"
      @@api_version = ""

      attr_accessor :connection_options

      def initialize(options = {})
        self.connection_options = options[:connection] || {}
        # {
        #   :certficate => "",
        #   :uri => ""
        # }
      end

      def get_student_by_api_id(api_id)
        get_students({:api_id => api_id, :limit => 1}).first
      end

      def get_student(params)
        get_students(params.merge(:limit => 1)).first
      end

      def get_students(params)
        if params.has_key?(:school) or params.has_key?(:school_api_id)
          school_api_id = params.delete(:school) || params.delete(:school_api_id)
          students = get_students_by_school(school_api_id, params)
        else
          threads = []
          get_schools.each do |school|
            threads << Thread.new do
              get_students_by_school(school, params)
            end
          end
          students = threads.collect(&:value).flatten.compact
        end
        filter_students_by_params(students, params)
      end

      def get_students_by_school(school, params = {})
        school_api_id = school.is_a?(School) ? school.api_id : school
        if params.has_key?(:api_id)
          path = "api/schools/#{school_api_id}/students/#{params[:api_id]}"
        elsif params.has_key?(:sis_student_id)
          path = "api/schools/#{school_api_id}/students/sn/#{params[:sis_student_id]}"
        else
          path = "api/schools/#{school_api_id}/students"
        end
        students_response_hash = self.request(:get, path, self.map_student_search_params(params))
        students_response_hash.collect{|shsh| Student.new(convert_to_student_data(shsh))}
      end

      def create_student(student)
        raise NotImplementedError
      end

      def update_student(student)
        raise NotImplementedError
      end

      def get_schools(params = {})
        schools_response_hash = self.request(:get, 'api/v2/schools', params)

        schools_response_hash.collect{|h| School.new(convert_to_school_data(h))}
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
        response_hash
      end

      protected

      def map_student_search_params(attrs)
        attrs
      end

      def convert_to_student_data(attrs)
        cattrs = {}

        cattrs[:first_name]        = attrs["FirstName"]
        cattrs[:middle_name]       = attrs["MiddleName"]
        cattrs[:last_name]         = attrs["LastName"]

        cattrs[:api_id]           = attrs["PermanentID"]
        cattrs[:sis_student_id]   = attrs["StudentNumber"]
        cattrs[:state_student_id] = attrs["StateStudentID"]

        cattrs[:gender]           = attrs["Sex"]
        if attrs["Birthdate"]
          begin
            cattrs[:birth_date] = Date.strptime(attrs["Birthdate"], DATE_FORMAT)
          rescue => e
            puts "#{e.inspect} #{bd}"
          end
        end

        #SchoolCode

        cattrs.reject{|k,v| v.respond_to?(:empty?) ? v.empty? : v.nil?}
      end

      def convert_to_school_data(attrs)
        cattrs = {}

        cattrs[:api_id] = attrs["SchoolCode"]
        cattrs[:name] = attrs["Name"]
        cattrs[:number] = attrs["SchoolCode"]

        cattrs.reject{|k,v| v.respond_to?(:empty?) ? v.empty? : v.nil?}
      end

      def headers_for_auth
        {
            'AERIES-CERT' => self.connection_options[:certificate],
            'Content-Type' => "application/json"
        }
      end

    end
  end
end
