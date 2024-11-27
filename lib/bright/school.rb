module Bright
  class School < Model
    @attribute_names = [:api_id, :name, :number, :state_id, :low_grade, :high_grade, :last_modified]
    attr_accessor(*@attribute_names)
    attr_accessor :address, :phone_number

    def address=(address)
      if address.is_a?(Address)
        @address = address
      elsif address.is_a?(Hash)
        @address = Address.new(address)
      end
    end

    def phone_number=(phone_number)
      if phone_number.is_a?(PhoneNumber)
        @phone_number = phone_number
      elsif phone_number.is_a?(Hash)
        @phone_number = PhoneNumber.new(phone_number)
      end
    end
  end
end
