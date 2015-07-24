require 'base64'

module Bright
  module SisApi
    class TSIS
      @@description = "Connects to the TIES API for accessing TIES TSIS student information"
      @@doc_url = "#unkown"
      
      attr_accessor :connection_options
      
      def initialize(options = {})
        self.connection_options = {
          :key => "0ee8c369d0b5",
          :secret => "3ff3adfe0d734259b451dd2c8ef672ae",
          :district_id => "8999",
          :uri => "https://apitest.tiescloud.net/v1.0"
        }
      end
      
      def get_student(params)
        self.get_students(params).first
      end
      
      def get_students(params)
        self.request(:get, 'Students/', self.map_student_params(params))
      end
      
      def create_student(student)
        raise NotImplementedError, "TSIS does not support creating students"
      end
      
      def update_student(student)
        raise NotImplementedError, "TSIS does not support updating students"
      end
      
      def request(method, path, params = {})
        uri  = "#{self.connection_options[:uri]}/#{path}"
        body = nil
        query = URI.encode(params.map{|k,v| "#{k}=#{v}"}.join("&"))
        if method == :get
          uri += "?#{query}"
        else
          body = query
        end
        
        headers = self.headers_for_auth(uri)

        connection = Bright::Connection.new(uri)
        response = connection.request(method, body, headers)
        raise response.body.inspect
      end
      
      protected
      
      def map_student_params(params)
        default_params = {"rpp" => 1000, "schoolyear" => Date.today.year}
        
        params["studentname"] = params.delete(:name)
        params["studentname"] ||= "#{params.delete(:first_name)} #{params.delete(:middle_name)} #{params.delete(:last_name)}"
        params["studentids"] = [params.delete(:state_student_id), params.delete(:sis_student_id)].compact.join(",")
        params = Hash[params.collect do |k,v|
          if v.is_a?(Array)
            v = v.join(",")
          end
          k = k.to_s.gsub(/[^A-Za-z]/, "").downcase
          [k,v]
        end]
        
        default_params.merge(params)
      end
      
      def headers_for_auth(uri)
        t = Time.now.utc.httpdate
        string_to_sign = "GET\n#{t}\n#{uri}"
        
        signature = Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha1'), self.connection_options[:secret], string_to_sign)).strip
        authorization = "TIES" + " " + self.connection_options[:key] + ":" + signature
    
        {
            'Authorization' => authorization,
            'DistrictNumber' => self.connection_options[:district_id],
            'ties-date' => t,
            'Content-Type' => "application/json"
        }
      end
    end
  end
end