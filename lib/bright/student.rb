module Bright
  class Student < Model
    attr_accessor :first_name, :middle_name, :last_name, :nick_name, :birth_date, :grade, :projected_graduation_year,
                  :gender, :hispanic_ethnicity, :race, :image, :primary_language, :secondary_language, :homeless_code,
                  :frl_status, :sis_student_id, :state_student_id, :last_modified
                  
    # TODO:: map contact info (addresses, email, phone, etc)

    def name
      "#{self.first_name} #{self.middle_name} #{self.last_name}".gsub(/\s+/, " ").strip
    end
    
    def <=>(other)
      (self.sis_student_id and self.sis_student_id == other.sis_student_id) or
      (self.state_student_id and self.state_student_id == other.state_student_id) or
      (self.first_name == other.first_name and self.middle_name == other.middle_name and self.last_name == other.last_name and self.birth_date == other.birth_date)
    end
    
  end
end


