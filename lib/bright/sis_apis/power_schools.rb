module Bright
  module SisApi
    class PowerSchools
      @@description = "Connects to the Power Schools API for accessing student information"
      @@doc_url = "http://psimages.sunnysideschools.org/api-developer-guide-1.6.0/"
      @@api_version = "1.6.0"
      
      def get_student(params)
        raise NotImplementedError
      end
      
      def get_students(params)
        raise NotImplementedError
      end
      
      def create_student(student)
        raise NotImplementedError
      end
      
      def update_student(student)
        raise NotImplementedError
      end
      
      def subscribe_student(student)
        raise NotImplementedError
      end
      
      def retrive_access_token
        "token"
      end
    end
  end
end