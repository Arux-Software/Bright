require 'securerandom'

module Bright
  class Contact < Model
    @attribute_names = [:client_id, :api_id, :first_name, :middle_name, :last_name, :nick_name,
                        :birth_date, :gender, :relationship_type,
                        :hispanic_ethnicity, :race, :image,
                        :sis_contact_id, :last_modified]
    attr_accessor *@attribute_names

    def self.attribute_names
      @attribute_names
    end

    attr_accessor :student, :phone_numbers, :addresses, :email_address

    def phone_numbers=(array)
      if array.size <= 0 or array.first.is_a?(PhoneNumber)
        @phone_numbers = array
      elsif array.first.is_a?(Hash)
        @phone_numbers = array.collect{|a| PhoneNumber.new(a)}
      end
      @phone_numbers ||= []
    end

    def phone_numbers
      @phone_numbers ||= []
    end

    def addresses=(array)
      if array.size <= 0 or array.first.is_a?(Address)
        @addresses = array
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

  end
end
