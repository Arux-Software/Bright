module Bright
  module SisApi
    class InfiniteCampus
      
      def get_student_by_api_id(api_id)
        raise NotImplementedError
      end
      
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
      
      def get_schools(params)
        raise NotImplementedError
      end
      
    end
  end
end