module Bright
  class Student < Model
    attr_accessor :first_name, :middle_name, :last_name, :nick_name, :birth_date, :grade, :projected_graduation_year,
                  :gender, :hispanic_ethnicity, :race, :image, :primary_language, :secondary_language, :homeless_code,
                  :frl_status, :sis_student_id, :state_student_id, :last_modified
                  
    # TODO:: map contact info (addresses, email, phone, etc)

    def name
      "#{self.first_name} #{self.middle_name} #{self.last_name}".gsub(/\s+/, " ")
    end
    
  end
end


