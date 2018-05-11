require 'securerandom'

module Bright
  class Student < Model
    @attribute_names = [:client_id, :api_id, :first_name, :middle_name, :last_name, :nick_name,
                        :birth_date, :grade, :grade_school_year, :projected_graduation_year, :gender,
                        :hispanic_ethnicity, :race, :image, :primary_language, :secondary_language,
                        :homeless_code, :frl_status, :sis_student_id,
                        :state_student_id, :last_modified]
    attr_accessor *@attribute_names

    def self.attribute_names
      @attribute_names
    end

    # TODO:: map contact info (addresses, email, phone, etc)
    attr_accessor :enrollment, :addresses, :email_address, :school

    def initialize(*args)
      super
      self.client_id ||= SecureRandom.uuid
      self
    end

    def name
      "#{self.first_name} #{self.middle_name} #{self.last_name}".gsub(/\s+/, " ").strip
    end

    def <=>(other)
      (self.sis_student_id and self.sis_student_id == other.sis_student_id) or
      (self.state_student_id and self.state_student_id == other.state_student_id) or
      (self.first_name == other.first_name and self.middle_name == other.middle_name and self.last_name == other.last_name and self.birth_date == other.birth_date)
    end

    alias id client_id

    def addresses=(array)
      if array.size <= 0 or array.first.is_a?(Address)
        @addresses = array
        @addresses.each{|a| a.student = self}
      elsif array.first.is_a?(Hash)
        @addresses = array.collect{|a| Address.new(a)}
      end
      @addresses ||= []
    end

    def addresses
      @addresses ||= []
    end

    def email_address=(email)
      if email.is_a?(EmailAddress)
        @email_address = email
      elsif email.is_a?(Hash)
        @email_address = EmailAddress.new(email)
      end
      @email_address
    end

    def school=(school_val)
      if school_val.is_a?(School)
        @school = school_val
      elsif school_val.is_a?(Hash)
        @school = School.new(school_val)
      end
      @school
    end

  end
end
