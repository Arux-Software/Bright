module Bright
  module SisApi
    class PowerSchools
      DATE_FORMAT = '%Y-%m-%d'
      
      @@description = "Connects to the Power Schools API for accessing student information"
      @@doc_url = "http://psimages.sunnysideschools.org/api-developer-guide-1.6.0/"
      @@api_version = "1.6.0"
      
      attr_accessor :connection_options, :expansion_options
      
      def initialize(options = {})
        self.connection_options = options[:connection] || {}
        self.expansion_options = options[:expansion] || {}
        # {
        #   :client_id => "",
        #   :client_secret => "",
        #   :uri => ""
        #   :access_token => "", #optional
        # }
      end
      
      def get_student(params, options = {})
        self.get_students(params, options.merge(:per_page => 1, :wrap_in_collection => false)).first
      end
      
      def get_students(params, options = {})
        params = self.apply_expansions(params)
        params = self.apply_options(params, options)

        if options[:wrap_in_collection] != false
          students_count_response_hash = self.request(:get, 'ws/v1/district/student/count', self.map_search_params(params))
          # {"resource"=>{"count"=>293}}
          total_results = students_count_response_hash["resource"]["count"].to_i if students_count_response_hash["resource"]
        end

        students_response_hash = self.request(:get, 'ws/v1/district/student', self.map_search_params(params))
   
        students_hash = [students_response_hash["students"]["student"]].flatten
        
        students = students_hash.compact.collect {|st_hsh|
          Student.new(convert_to_student_data(st_hsh))
        }
        
        if options[:wrap_in_collection] != false
          api = self
          load_more_call = proc { |page|
            # pages start at one, so add a page here
            api.get_students(params, {:wrap_in_collection => false, :page => (page + 1)})
          }

          ResponseCollection.new({
            :seed_page => students, 
            :total => total_results,
            :per_page => params[:pagesize], 
            :load_more_call => load_more_call
          })
        else
          students
        end
      end
      
      def create_student(student, additional_params = {})
        response = self.request(:post, 'ws/v1/student', self.convert_from_student_data(student, "INSERT", additional_params))
        puts "#{response.inspect}"
        student
      end
      
      def update_student(student, additional_params = {})
        response = self.request(:post, 'ws/v1/student', self.convert_from_student_data(student, "UPDATE", additional_params))
        puts "#{response.inspect}"
        student
      end
      
      def subscribe_student(student)
        raise NotImplementedError
      end
      
      def retrive_access_token
        connection = Bright::Connection.new("#{self.connection_options[:uri]}/oauth/access_token/")
        response = connection.request(:post, "grant_type=client_credentials", self.headers_for_access_token)
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
        end
        response_hash
      end
      
      protected
      
      def map_search_params(params)
        params = params.dup
        default_params = {}
        
        q = ""
        %w(first_name middle_name last_name).each do |f|
          if fn = params.delete(f.to_sym)
            q += %(name.#{f}==#{fn};)
          end
        end
        if lid = params.delete(:sis_student_id)
          q += %(local_id==#{lid};)
        end
        if sid = params.delete(:state_student_id)
          q += %(state_province_id==#{sid};)
        end
        params[:q] = q

        default_params.merge(params).reject{|k,v| v.respond_to?(:empty?) ? v.empty? : v.nil?}
      end
      
      def convert_to_student_data(attrs)
        cattrs = {}
        
        if attrs["name"]
          cattrs[:first_name]  = attrs["name"]["first_name"]
          cattrs[:middle_name] = attrs["name"]["middle_name"]
          cattrs[:last_name]  = attrs["name"]["last_name"]
        end
        
        cattrs[:api_id] = attrs["id"].to_s
        cattrs[:sis_student_id] = attrs["local_id"].to_s
        cattrs[:state_student_id]   = attrs["state_province_id"].to_s
        
        if attrs["demographics"]
          if attrs["demographics"]["birth_date"]
            begin 
              cattrs[:birth_date] = Date.strptime(attrs["demographics"]["birth_date"], DATE_FORMAT)
            rescue => e
              puts "#{e.inspect} #{bd}"
            end
          end

          cattrs[:gender] = attrs["demographics"]["gender"]

          pg = attrs["demographics"]["projected_graduation_year"].to_i
          cattrs[:projected_graduation_year] = pg if pg > 0
        end
        
        cattrs.reject{|k,v| v.respond_to?(:empty?) ? v.empty? : v.nil?}
      end
      
      def convert_from_student_data(student, action = nil, additional_params = {})
        {:students => 
          {:student =>
            {
              :client_uid => student.client_id,
              :action => action,
              :id => student.api_id,
              :local_id => student.sis_student_id,
              :state_province_id => student.state_student_id,
              :name => {
                :first_name => student.first_name,  
                :middle_name => student.middle_name,
                :last_name => student.last_name
              }.reject{|k,v| v.respond_to?(:empty?) ? v.empty? : v.nil?},
              :demographics => {
                :gender => student.gender,
                :birth_date => (student.birth_date ? student.birth_date.strftime(DATE_FORMAT) : nil),
                :projected_graduation_year => student.projected_graduation_year
              }.reject{|k,v| v.respond_to?(:empty?) ? v.empty? : v.nil?}
            }.merge(additional_params).reject{|k,v| v.respond_to?(:empty?) ? v.empty? : v.nil?}
          }
        }
      end
      
      def apply_expansions(params)
        if self.expansion_options.empty?
          hsh = self.request(:get, 'ws/v1/district/student', {:pagesize => 1, :q => "local_id==0"})
          if hsh and hsh["students"]
            self.expansion_options = {
              :expansions => hsh["students"]["@expansions"].to_s.split(", "),
              :extensions => hsh["students"]["@extensions"].to_s.split(", "),
            }
          end
        end

        params.merge({
          :expansions => (%w(demographics addresses ethnicity_race phones) & (self.expansion_options[:expansions] || [])).join(","),
          :extensions => (%w(studentcorefields) & (self.expansion_options[:extensions] || [])).join(",")
        })
      end
      
      def apply_options(params, options)
        options[:per_page] = params[:pagesize] ||= params.delete(:per_page) || options[:per_page] || 100
        params[:page] ||= options[:page]
        params
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