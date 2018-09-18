module Bright
  class PhoneNumber < Model
    @attribute_names = [:phone_number, :type]
    attr_accessor *@attribute_names
    TYPES = ["Cell", "Home", "Work", "Other"]

    def phone_number=(number)
      @phone_number = number.gsub(/[^0-9]/, "")
    end

  end
end
