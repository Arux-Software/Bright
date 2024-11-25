require "securerandom"

module Bright
  class Student < Model
    @attribute_names = [:client_id, :api_id, :first_name, :middle_name, :last_name, :nick_name,
      :birth_date, :grade, :grade_school_year, :projected_graduation_year, :sex,
      :hispanic_ethnicity, :race, :image, :primary_language, :secondary_language,
      :homeless_code, :frl_status, :sis_student_id,
      :state_student_id, :last_modified]
    attr_accessor(*@attribute_names)

    def self.attribute_names
      @attribute_names
    end

    # TODO:: map contact info (addresses, email, phone, etc)
    attr_accessor :enrollment, :addresses, :email_address, :phone_numbers, :school, :contacts

    def initialize(*args)
      super
      self.client_id ||= SecureRandom.uuid
    end

    def name
      "#{first_name} #{middle_name} #{last_name}".gsub(/\s+/, " ").strip
    end

    def <=>(other)
      (sis_student_id and sis_student_id == other.sis_student_id) or
        (state_student_id and state_student_id == other.state_student_id) or
        (first_name == other.first_name and middle_name == other.middle_name and last_name == other.last_name and birth_date == other.birth_date)
    end

    alias_method :id, :client_id

    def addresses=(array)
      if array.size <= 0 or array.first.is_a?(Address)
        @addresses = array
        @addresses.each { |a| a.student = self }
      elsif array.first.is_a?(Hash)
        @addresses = array.collect { |a| Address.new(a) }
      end
      @addresses ||= []
    end

    def addresses
      @addresses ||= []
    end

    def phone_numbers=(array)
      if array.size <= 0 or array.first.is_a?(PhoneNumber)
        @phone_numbers = array
      elsif array.first.is_a?(Hash)
        @phone_numbers = array.collect { |a| PhoneNumber.new(a) }
      end
      @phone_numbers ||= []
    end

    def phone_numbers
      @phone_numbers ||= []
    end

    def email_address=(email)
      if email.is_a?(EmailAddress)
        @email_address = email
      elsif email.is_a?(Hash)
        @email_address = EmailAddress.new(email)
      end
    end

    def school=(school_val)
      if school_val.is_a?(School)
        @school = school_val
      elsif school_val.is_a?(Hash)
        @school = School.new(school_val)
      end
    end

    def contacts=(array)
      if array.size <= 0 or array.first.is_a?(Contact)
        @contacts = array
      elsif array.first.is_a?(Hash)
        @contacts = array.collect { |a| Contact.new(a) }
      end
      @contacts ||= []
    end

    def contacts
      @contacts ||= []
    end
  end
end
