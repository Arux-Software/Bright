module Bright
  module SisApi
    class Base
      
      def filter_students_by_params(students, params)
        total = params[:limit]
        count = 0
        found = []
  
        keys = (Student.attribute_names & params.keys.collect(&:to_sym))
        puts "filtering on #{keys.join(",")}"
        students.each do |student|
          break if total and count >= total
    
          should = (keys).all? do |m|
            student.send(m) =~ Regexp.new(Regexp.escape(params[m]), Regexp::IGNORECASE)
          end
          count += 1 if total and should
          found << student if should
        end
        found
      end
  
    end
  end
end